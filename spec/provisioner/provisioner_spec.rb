require 'spec_helper'
require 'vagrant-windows-domain/provisioner'
require 'vagrant-windows-domain/config'
require 'rspec/its'

describe VagrantPlugins::WindowsDomain::Provisioner do
  include_context "unit"

  let(:root_path)           { (Pathname.new(Dir.mktmpdir)).to_s }
  let(:ui)                  { double("ui") }
  let(:machine)             { double("machine", ui: ui) }
  let(:env)                 { double("environment", root_path: root_path, ui: ui) }
  let(:vm)                  { double ("vm") }
  let(:communicator)        { double ("communicator") }
  let(:shell)               { double ("shell") }
  let(:powershell)          { double ("powershell") }
  let(:guest)               { double ("guest") }
  let(:configuration_file)  { "manifests/MyWebsite.ps1" }
  let(:module_path)         { ["foo/modules", "foo/modules2"] }
  let(:root_config)         { VagrantPlugins::WindowsDomain::Config.new }
  subject                   { described_class.new machine, root_config }

  describe "configure" do
    before do
      allow(machine).to receive(:root_config).and_return(root_config)
      machine.stub(config: root_config, env: env)
      allow(ui).to receive(:say).with(any_args)
      allow(machine).to receive(:communicate).and_return(communicator)
      allow(communicator).to receive(:shell).and_return(shell)
      allow(shell).to receive(:powershell).with("$env:COMPUTERNAME").and_yield(:stdout, "myoldcomputername")      
      allow(root_config).to receive(:vm).and_return(vm)
      allow(vm).to receive(:communicator).and_return(:winrm)
      root_config.finalize!
      root_config.validate(machine)
    end

    it "should confirm if the OS is Windows" do
      allow(communicator).to receive(:sudo).twice
      expect(subject.windows?).to eq(true)
      subject.configure(root_config)
    end

    it "should error if the detected OS is not Windows" do
      allow(vm).to receive(:communicator).and_return(:ssh)
      expect { subject.configure(root_config) }.to raise_error("Unsupported platform detected. Vagrant Windows Domain only works on Windows guest environments.")
    end

    it "should verify the guest has the required powershell cmdlets/capabilities" do
      expect(communicator).to receive(:sudo).with("which Add-Computer", {:error_class=>VagrantPlugins::WindowsDomain::WindowsDomainError, :error_key=>:binary_not_detected, :domain=>nil, :binary=>"Add-Computer"})
      expect(communicator).to receive(:sudo).with("which Remove-Computer", {:error_class=>VagrantPlugins::WindowsDomain::WindowsDomainError, :error_key=>:binary_not_detected, :domain=>nil, :binary=>"Remove-Computer"})
      subject.configure(root_config)
    end
  end

  describe "provision" do

    before do
      allow(machine).to receive(:root_config).and_return(root_config)
      machine.stub(config: root_config, env: env)
      allow(ui).to receive(:say).with(any_args)
      allow(machine).to receive(:communicate).and_return(communicator)
      allow(communicator).to receive(:shell).and_return(shell)
      allow(shell).to receive(:powershell).with("$env:COMPUTERNAME").and_yield(:stdout, "myoldcomputername")      
      allow(root_config).to receive(:vm).and_return(vm)
      allow(vm).to receive(:communicator).and_return(:winrm)
      expect(communicator).to receive(:sudo).with("which Add-Computer", {:error_class=>VagrantPlugins::WindowsDomain::WindowsDomainError, :error_key=>:binary_not_detected, :domain=>"foo.com", :binary=>"Add-Computer"})
      expect(communicator).to receive(:sudo).with("which Remove-Computer", {:error_class=>VagrantPlugins::WindowsDomain::WindowsDomainError, :error_key=>:binary_not_detected, :domain=>"foo.com", :binary=>"Remove-Computer"})

      root_config.domain = "foo.com"
      root_config.username = "username"
      root_config.password = "password"

      root_config.finalize!
      root_config.validate(machine)
      subject.configure(root_config)
    end

    it "should join the domain" do
      # subject.provision
    end

    it "should restart the machine on a successful domain join" do

    end

    it "should not restart the machine on a failed domain join attempt" do

    end

    it "should not attempt to join the domain if already on it" do

    end

    it "should authenticate with credentials if provided" do

    end

    it "should not authenticate at all if 'unsecure' option provided" do

    end

    it "should prompt for credentials if not provided" do
      root_config.username = nil
      root_config.password = nil
      expect(ui).to receive(:ask).with("Please enter your domain password (output will be hidden): ", {:echo=>false}).and_return("myusername")
      expect(ui).to receive(:ask).with("Please enter your domain username: ")
      subject.set_credentials
    end

    it "should not prompt for credentials if provided" do
      expect(ui).to_not receive(:ask)
      subject.set_credentials
    end

    it "should remove any traces of credentials once provisioning has occurred" do
      expect(communicator).to receive(:sudo).with("del c:/tmp/vagrant-windows-domain-runner.ps1")
      subject.remove_command_runner_script
    end

  end

  describe "cleanup" do

    it "should leave domain when a `vagrant destroy` is issued" do
      allow(machine).to receive(:communicate).and_return(communicator)
      expect(communicator).to receive(:upload)
      expect(communicator).to receive(:sudo).with(". 'c:/tmp/vagrant-windows-domain-runner.ps1'", {:elevated=>true, :error_key=>:ssh_bad_exit_status_muted, :good_exit=>0, :shell=>:powershell})
      expect(ui).to receive(:info).with(any_args).once
      
      subject.cleanup
    end

    it "should ask for credentials when leaving domain when no credentials were provided" do
      root_config.username = nil
      root_config.password = nil      
      allow(machine).to receive(:communicate).and_return(communicator)
      allow(machine).to receive(:env).and_return(env)
      expect(communicator).to receive(:upload)
      expect(communicator).to receive(:sudo).with(". 'c:/tmp/vagrant-windows-domain-runner.ps1'", {:elevated=>true, :error_key=>:ssh_bad_exit_status_muted, :good_exit=>0, :shell=>:powershell})
      expect(ui).to receive(:info).with(any_args).once
      expect(ui).to receive(:ask).with("Please enter your domain password (output will be hidden): ", {:echo=>false}).and_return("myusername")
      expect(ui).to receive(:ask).with("Please enter your domain username: ")      

      subject.cleanup
    end

  end

  # describe "Powershell runner script" do
#     before do
#       # Prevent counters messing with output in tests
#       Vagrant::Util::Counter.class_eval do
#         def get_and_update_counter(name=nil) 1 end
#       end

#       allow(machine).to receive(:root_config).and_return(root_config)
#       root_config.configuration_file = configuration_file
#       machine.stub(config: root_config, env: env)
#       root_config.module_path = module_path
#       root_config.configuration_file = configuration_file
#       root_config.finalize!
#       root_config.validate(machine)
#       subject.configure(root_config)

#     end

#     context "with default parameters" do
#       it "should generate a valid powershell command" do
#         script = subject.generate_dsc_runner_script
#         expect_script = "#
# # DSC Runner.
# #
# # Bootstraps the DSC environment, sets up configuration data
# # and runs the DSC Configuration.
# #
# #

# # Set the local PowerShell Module environment path
# $absoluteModulePaths = [string]::Join(\";\", (\"/tmp/vagrant-windows-domain-1/modules-0;/tmp/vagrant-windows-domain-1/modules-1\".Split(\";\") | ForEach-Object { $_ | Resolve-Path }))

# echo \"Adding to path: $absoluteModulePaths\"
# $env:PSModulePath=\"$absoluteModulePaths;${env:PSModulePath}\"
# (\"/tmp/vagrant-windows-domain-1/modules-0;/tmp/vagrant-windows-domain-1/modules-1\".Split(\";\") | ForEach-Object { gci -Recurse  $_ | ForEach-Object { Unblock-File  $_.FullName} })

# $script = $(Join-Path \"/tmp/vagrant-windows-domain-1\" \"manifests/MyWebsite.ps1\" -Resolve)
# echo \"PSModulePath Configured: ${env:PSModulePath}\"
# echo \"Running Configuration file: ${script}\"

# # Generate the MOF file, only if a MOF path not already provided.
# # Import the Manifest
# . $script

# cd \"/tmp/vagrant-windows-domain-1\"
# $StagingPath = $(Join-Path \"/tmp/vagrant-windows-domain-1\" \"staging\")
# $response = MyWebsite -OutputPath $StagingPath  4>&1 5>&1 | Out-String

# # Start a DSC Configuration run
# $response += Start-DscConfiguration -Force -Wait -Verbose -Path $StagingPath 4>&1 5>&1 | Out-String
# $response"

#         expect(script).to eq(expect_script)
#       end
#     end

#   end

#   describe "write DSC Runner script" do
#     it "should upload the customised DSC runner to the guest" do
#       script = "myscript"
#       path = "/local/runner/path"
#       guest_path = "c:/tmp/vagrant-windows-domain-runner.ps1"
#       machine.stub(config: root_config, env: env, communicate: communicator)
#       file = double("file")
#       allow(file).to receive(:path).and_return(path)
#       allow(Tempfile).to receive(:new) { file }
#       expect(file).to receive(:write).with(script)
#       expect(file).to receive(:fsync)
#       expect(file).to receive(:close).exactly(2).times
#       expect(file).to receive(:unlink)
#       expect(communicator).to receive(:upload).with(path, guest_path)
#       res = subject.write_dsc_runner_script(script)
#       expect(res.to_s).to eq(guest_path)
#     end
#   end

#   describe "Apply DSC" do
#     it "should invoke the DSC Runner and notify the User of provisioning status" do
#       expect(ui).to receive(:info).with(any_args).once
#       expect(ui).to receive(:info).with("provisioned!", {color: :green, new_line: false, prefix: false}).once
#       allow(machine).to receive(:communicate).and_return(communicator)
#       expect(communicator).to receive(:sudo).with('. ' + "'c:/tmp/vagrant-windows-domain-runner.ps1'",{:elevated=>true, :error_key=>:ssh_bad_exit_status_muted, :good_exit=>0, :shell=>:powershell}).and_yield(:stdout, "provisioned!")

#       subject.run_dsc_apply
#     end

#     it "should show error output in red" do
#       expect(ui).to receive(:info).with(any_args).once
#       expect(ui).to receive(:info).with("provisioned!", {color: :red, new_line: false, prefix: false}).once
#       allow(machine).to receive(:communicate).and_return(communicator)
#       expect(communicator).to receive(:sudo).with('. ' + "'c:/tmp/vagrant-windows-domain-runner.ps1'",{:elevated=>true, :error_key=>:ssh_bad_exit_status_muted, :good_exit=>0, :shell=>:powershell}).and_yield(:stderr, "provisioned!")

#       subject.run_dsc_apply
    # end
  # end
end