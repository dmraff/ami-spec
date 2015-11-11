require 'ami_spec/aws_instance'
require 'ami_spec/server_spec'

module AmiSpec
  class InstanceCreationTimeout < StandardError; end
  # == Parameters:
  # amis::
  #   A hash of roles and amis in the format of:
  #   {role => ami_id}. i.e.
  #   {'web_server' => 'ami-abcd1234'}
  # specs::
  #   A string of the directory to find ServerSpecs.
  #   There should be a folder in this directory for each role found in ::amis
  # subnet_id::
  #   The subnet_id to start instances in.
  # key_name::
  #   The SSH key name to assign to instances. This key name must exist on the executing host for passwordless login.
  # aws_options::
  #   A hash of AWS options. Possible values are:
  #   - region (defaults to AWS_DEFAULT_REGION)
  #   - security_group_ids (defaults to the default security group for the VPC)
  #   - instance_type (defaults to t2.micro)
  def self.run(amis:, specs:, subnet_id:, key_name:, aws_options: {})


    wait_until_running

    instances = []

    amis.each_pair do |role, ami|
      instances.push(
        AwsInstance.start(role: role, ami: ami, subnet_id: subnet_id, key_name: key_name, options: aws_options)
      )
    end

    timeout = 300
    until instances.all? { |ec2| ec2.state.name == 'running' } || timeout < 1
      sleep 1
      timeout = timeout - 1
    end

    if timeout < 1
      raise InstanceCreationTimeout.new(
        "Some instances have not started yet. #{ instances.collect(&:instance_id) }"
      )
    end

    results = []
    instances.each do |ec2|
      results.push(ServerSpec.run(instance: ec2, specs: specs).result)
    end

    results.all?
  ensure
    instances.each do |ec2|
      begin
        ec2.terminate
      rescue Aws::EC2::Errors::InvalidInstanceIDNotFound
        # Ignore since some instances may not have started/been created
      end
    end
  end
end