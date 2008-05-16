module RobotArmy
  class TaskMaster < Thor
    def self.host(host=nil)
      @host = host if host
      @host
    end
    
    def host
      self.class.host
    end
    
    def say(something)
      puts "** #{something}"
    end
    
    def self.loader
      @loader ||= RobotArmy::Loader
    end
    
    def self.loader=(loader)
      @loader = loader
    end
    
    def loader
      @loader ||= self.class.loader.new
    end
    
    def remote(host=self.host, &proc)
      ##
      ## bootstrap the child process
      ##
      
      # small hack to retain control of stdin
      cmd = %{ruby -rbase64 -e "eval(Base64.decode64(STDIN.gets('|')))"}
      cmd = "ssh #{host} #{cmd}" if host
      
      stdin, stdout, stderr = Open3.popen3 cmd
      stdin.sync = stdout.sync = stderr.sync = true
      
      loader.libraries.replace $TESTING ? 
        [File.join(File.dirname(__FILE__), '..', 'robot-army')] : ['robot-army']
      
      code = loader.render
      code = Base64.encode64(code)
      stdin << code << '|'
      
      
      ##
      ## build the code to send it
      ##
      
      # fix stack traces
      file, line = eval('[__FILE__, __LINE__]', proc.binding)
      
      # include local variables
      locals = eval('local_variables', proc.binding).map do |name|
        "#{name} = Marshal.load(#{Marshal.dump(eval(name, proc.binding)).inspect})"
      end
      
      code = %{
        #{locals.join("\n")}  # all local variables
        #{proc.to_ruby(true)} # the proc itself
      }
      
      
      ##
      ## send the child a message
      ##
      
      messenger = RobotArmy::Messenger.new(stdout, stdin)
      messenger.post(:command => :eval, :data => {
        :code => code, 
        :file => file, 
        :line => line
      })
      
      ##
      ## get and evaluate the response
      ##
      
      response = messenger.get
      
      case response[:status]
      when 'ok'
        return response[:data]
      when 'error'
        raise response[:data]
      else
        raise RuntimeError, "Unknown response status from remote process: #{response[:status]}"
      end
    end
    
    def self.mock
      new(:noop, {})
    end
    
    private
    
    def noop
      # this only exists so that we can call something that'll do nothing
    end
  end
end
