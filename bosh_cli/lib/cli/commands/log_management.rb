# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class LogManagement < Base
    # bosh logs
    usage 'logs'
    desc 'Fetch job or agent logs from a BOSH-managed VM'
    option '--agent', 'fetch agent logs'
    option '--job', 'fetch job logs'
    option '--only filter1,filter2,...', Array,
           'only fetch logs that satisfy',
           'given filters (defined in job spec)'
    option '--all', 'fetch all files in the job or agent log directory'
    option '--dir destination_directory', String, 'download directory'
    def fetch_logs(job, index = nil)
      index = valid_index_for(job, index)
      check_arguments(index)

      resource_id = fetch_log_resource_id(index, job)
      log_file_path = log_file_destination(index, job)
      download_logs(log_file_path, resource_id)
    end

    def fetch_log_resource_id(index, job)
      resource_id = director.fetch_logs(deployment_name, job, index, log_type, filters)
      err('Error retrieving logs') if resource_id.nil?

      resource_id
    end

    private

    def agent_logs_wanted?
      options[:agent]
    end

    def job_logs_wanted?
      options[:job]
    end

    def download_logs(log_file_path, resource_id)
      say("Downloading log bundle (#{resource_id.to_s.make_green})...")

      begin
        tmp_file = director.download_resource(resource_id)
        FileUtils.mv(tmp_file, log_file_path)
        say("Logs saved in `#{log_file_path.make_green}'")
      rescue Bosh::Cli::DirectorError => e
        err("Unable to download logs from director: #{e}")
      ensure
        FileUtils.rm_rf(tmp_file) if tmp_file && File.exists?(tmp_file)
      end
    end

    def check_arguments(index)
      auth_required
      no_track_unsupported

      err('Job index is expected to be a positive integer') if index !~ /^\d+$/

      if agent_logs_wanted? && options[:only]
        err('Custom filtering is not supported for agent logs')
      end
    end

    def log_type
      err("You can't use --job and --agent together") if job_logs_wanted? && agent_logs_wanted?

      if agent_logs_wanted?
        'agent'
      else
        'job'
      end
    end

    def filters
      if options[:only]
        err("You can't use --only and --all together") if options[:all]
        filter = options[:only].join(',')
      elsif options[:all]
        filter = 'all'
      else
        filter = nil
      end
      filter
    end

    def log_file_destination(index, job)
      time = Time.now.strftime('%Y-%m-%d@%H-%M-%S')
      File.join(log_directory, "#{job}.#{index}.#{time}.tgz")
    end

    def log_directory
      options[:dir] || Dir.pwd
    end

    def deployment_name
      prepare_deployment_manifest['name']
    end
  end
end

