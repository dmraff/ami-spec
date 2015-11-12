# Loading serverspec first causes a weird error - stack level too deep
# Requiring rspec first fixes that *shrug*
require 'rspec'
require 'serverspec'

module AmiSpec
  class ServerSpec
    def self.run(args)
      new(args).tap(&:run)
    end

    def initialize(options)
      instance = options.fetch(:instance)
      private_ip = options.fetch(:private_ip, true)

      @ip = private_ip ? instance.private_ip_address : instance.public_ip_address
      @role = instance.tags.find{ |tag| tag.key == 'AmiSpec' }.value
      @spec = options.fetch(:spec)
      @user = options.fetch(:user)
      @key_file = options.fetch(:key_file)
    end

    def run
      $LOAD_PATH.unshift(@spec) unless $LOAD_PATH.include?(@spec)
      require File.join(@spec, 'spec_helper')

      set :backend, :ssh
      set :host, @ip
      set :ssh_options, :user => @user, :keys => [@key_file]
      RSpec::Core::Runner.disable_autorun!
      RSpec::Core::Runner.run(Dir.glob("#{@spec}/#{@role}/*_spec.rb"))
    end
  end
end
