require 'orc/namespace'
require 'orc/config'
require 'orc/model/application'
require 'orc/engine'
require 'orc/mismatch_resolver'
require 'client/deploy_client'
require 'cmdb/yaml'
require 'cmdb/git'
require 'cmdb/high_level_orchestration'
require 'progress/log'

class Orc::Factory
  attr_reader :application, :environment
  def initialize(options={})
    @application = options[:application]
    @environment = options[:environment]
  end
  def config_location
    "#{ENV['HOME']}/.orc.yaml"
  end
  def config
    @config ||= Orc::Config.new(config_location)
  end
  def cmdb
    @cmdb ||= CMDB::Yaml.new( :data_dir => config['cmdb_local_path'])
  end

  def remote_client
    @remote_client ||= Client::DeployClient.new(
      :environment => environment,
      :application => application
    )
  end

  def cmdb_git
    @cmdb_git ||= CMDB::Git.new(
      :origin     => config['cmdb_repo_url'],
      :local_path => config['cmdb_local_path']
    )
  end

  def high_level_orchestration
    @high_level_orchestration||= CMDB::HighLevelOrchrestration.new(
        :cmdb => cmdb,
        :git => cmdb_git,
        :environment => environment,
        :application => application
    )
  end

  def engine
    mismatch_resolver = Orc::MismatchResolver.new(remote_client)
    logger = Progress.logger()
    app_model = Orc::Model::Application.new(
      :remote_client      => remote_client,
      :cmdb               => cmdb,
      :environment        => environment,
      :application        => application,
      :progress_logger    => logger,
      :mismatch_resolver  => mismatch_resolver
    )

    Orc::Engine.new(
      :application_model => app_model,
      :log               => logger
    )
  end
end

