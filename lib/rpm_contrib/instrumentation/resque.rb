
module RPMContrib
  module Instrumentation
    # == Resque Instrumentation
    #
    # Installs a hook to ensure the agent starts manually when the worker
    # starts and also adds the tracer to the process method which executes
    # in the forked task.
    module ResqueInstrumentation
      ::Resque::Job.class_eval do
        include NewRelic::Agent::Instrumentation::ControllerInstrumentation
        
        old_perform_method = instance_method(:perform)

        define_method(:perform) do
          puts "Starting NewRelic injected perform"
          class_name = (payload_class ||self.class).name
          puts "reseting stats"
          NewRelic::Agent.reset_stats if NewRelic::Agent.respond_to? :reset_stats
          puts "performing action with newrelic trace"
          perform_action_with_newrelic_trace(:name => 'perform', :class_name => class_name,
                                             :category => 'OtherTransaction/ResqueJob') do
            puts "calling original perform method"
            r = old_perform_method.bind(self).call
            puts "returned from original perform with #{r.inspect}"
            r
          end
          unless defined?(::Resque.before_child_exit)
            puts "calling agent shutdown"
            NewRelic::Agent.shutdown
            puts "done calling agent shutdown"
          end
          puts "finally leaving injected perform"
        end
      end

      if defined?(::Resque.before_child_exit)
        ::Resque.before_child_exit do |worker|
          puts "calling agent shutdown in before_child_exit"
          NewRelic::Agent.shutdown
          puts "done calling agent shutdown"
        end
      end
    end
  end
end if defined?(::Resque::Job) and not NewRelic::Control.instance['disable_resque']
