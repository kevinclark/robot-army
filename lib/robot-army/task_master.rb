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
    
    def connection
      RobotArmy::GateKeeper.shared_instance.connect(host)
    end
    
    def remote(host=self.host, &proc)
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
      
      connection.messenger.post(:command => :eval, :data => {
        :code => code, 
        :file => file, 
        :line => line
      })
      
      ##
      ## get and evaluate the response
      ##
      
      response = connection.messenger.get
      connection.handle_response(response)
    end
  end
end
