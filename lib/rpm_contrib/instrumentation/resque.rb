
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
          NewRelic::Control.instance.setup_log # ensure we're not logging to STDOUT
          NewRelic::Control.instance.log.info "Starting NewRelic injected perform"
          class_name = (payload_class ||self.class).name
          NewRelic::Control.instance.log.info "reseting stats"
          NewRelic::Agent.reset_stats if NewRelic::Agent.respond_to? :reset_stats
          NewRelic::Control.instance.log.info "performing action with newrelic trace"
          perform_action_with_newrelic_trace(:name => 'perform', :class_name => class_name,
                                             :category => 'OtherTransaction/ResqueJob') do
            NewRelic::Control.instance.log.info "calling original perform method"
            r = old_perform_method.bind(self).call
            NewRelic::Control.instance.log.info "returned from original perform with #{r.inspect}"
            r
          end
          unless defined?(::Resque.before_child_exit)
            NewRelic::Control.instance.log.info "calling agent shutdown"
            NewRelic::Agent.shutdown
            NewRelic::Control.instance.log.info "done calling agent shutdown"
          end
          NewRelic::Control.instance.log.info "finally leaving injected perform"
        end
      end

      if defined?(::Resque.before_child_exit)
        ::Resque.before_child_exit do |worker|
          NewRelic::Control.instance.log.info "calling agent shutdown in before_child_exit"
          NewRelic::Agent.shutdown
          NewRelic::Control.instance.log.info "done calling agent shutdown"
        end
      end
    end
  end
end if defined?(::Resque::Job) and not NewRelic::Control.instance['disable_resque']
