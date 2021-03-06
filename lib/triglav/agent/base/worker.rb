require 'triglav/agent/timer'

module Triglav::Agent
  module Base
    # Triglav agent worker module for Serverengine.
    #
    # You usually do not need to customize this module, but if you want to
    # implement your original, configure
    #
    #     Triglav::Agent::Configuration.worker_module
    module Worker
      # serverengine interface
      def initialize
        @timer = Timer.new
      end

      # serverengine interface
      def reload
        $logger.info { "Worker#reload worker_id:#{worker_id}" }
        $setting.reload
      end

      # serverengine interface
      def run
        $logger.info { "Worker#run worker_id:#{worker_id}" }
        start
        until @stop
          @timer.wait(monitor_interval) { process }
        end
      rescue => e
        # ServerEngine.dump_uncaught_error does not tell me e.class
        log_error(e)
        raise e
      end

      def process
        started = Time.now
        $logger.info { "Start Worker#process worker_id:#{worker_id}" }

        total_count = 0
        total_success_count = 0
        resource_uri_prefixes.each do |resource_uri_prefix|
          break if stopped?
          processor = processor_class.new(self, resource_uri_prefix)
          total_count += processor.total_count
          total_success_count += processor.process
        end

        elapsed = Time.now - started
        $logger.info {
          "Finish Worker#process worker_id:#{worker_id} " \
          "success_count/total_count:#{total_success_count}/#{total_count} elapsed:#{elapsed.to_f}sec"
        }
      end

      def start
        @timer.start
        @stop = false
      end

      # serverengine interface
      def stop
        $logger.info { "Worker#stop worker_id:#{worker_id}" }
        @stop = true
        @timer.stop
      end

      def stopped?
        @stop
      end

      private

      def processor_class
        Configuration.processor_class
      end

      def name
        Configuration.name
      end

      def log_error(e)
        $logger.error { "#{e.class} #{e.message} #{e.backtrace.join("\\n")}" } # one line
      end

      def monitor_interval
        $setting.dig(name, :monitor_interval) || 60
      end

      def resource_uri_prefixes
        $setting.dig(name, :connection_info).keys
      end
    end
  end
end
