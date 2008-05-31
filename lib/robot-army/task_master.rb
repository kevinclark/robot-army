module RobotArmy
  class TaskMaster < Thor
    
    def initialize(*args)
      super
      @dep_loader = DependencyLoader.new
    end
    
    def self.host(host=nil)
      @host = host if host
      @host
    end
    
    def host
      @host || self.class.host
    end
    
    def host=(host)
      @host = host
    end
    
    def say(something)
      puts "** #{something}"
    end
    
    def connection
      RobotArmy::GateKeeper.shared_instance.connect(host)
    end
    
    def dependency(dep, ver = nil)
      @dep_loader.add_dependency dep, ver
    end
    
    def remote_eval(options, &proc)
      ##
      ## build the code to send it
      ##
      
      # fix stack traces
      file, line = eval('[__FILE__, __LINE__]', proc.binding)
      
      # include local variables
      locals = eval('local_variables', proc.binding).map do |name|
        "#{name} = Marshal.load(#{Marshal.dump(eval(name, proc.binding)).inspect})"
      end
      
      # include dependency loader
      dep_loading = "Marshal.load(#{Marshal.dump(@dep_loader).inspect}).load!"
      
      code = %{
        #{dep_loading} # load dependencies
        #{locals.join("\n")}  # all local variables
        #{proc.to_ruby(true)} # the proc itself
      }
      
      options[:file] = file
      options[:line] = line
      options[:code] = code
      
      ##
      ## send the child a message
      ##
      
      connection.messenger.post(:command => :eval, :data => options)
      
      ##
      ## get and evaluate the response
      ##
      
      response = connection.messenger.get
      connection.handle_response(response)
    end
    
    def ask_for_password(user)
      require 'highline'
      HighLine.new.ask("[sudo] #{user}@#{host||'localhost'} password: ") {|q| q.echo = false}
    end
    
    def sudo(host=self.host, &proc)
      @sudo_password ||= ask_for_password('root')
      remote_eval :host => host, :user => 'root', :password => @sudo_password, &proc
    end
    
    def remote(host=self.host, &proc)
      remote_eval :host => host, &proc
    end
  end
end
