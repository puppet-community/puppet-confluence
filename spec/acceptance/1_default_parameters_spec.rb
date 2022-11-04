# frozen_string_literal: true

require 'spec_helper_acceptance'

# It is sometimes faster to host confluence / java files on a local webserver.
# Set environment variable download_url to use local webserver
# export BEAKER_FACTER_DOWNLOAD_URL = 'http://10.0.0.XXX/'

describe 'confluence' do
  it 'installs with defaults' do
    pp = <<-EOS
      $jh = '/opt/java'
      $allow_virtual_packages = hiera('allow_virtual_packages',false)
      Package {
        allow_virtual => $allow_virtual_packages,
      }
      deploy::file { 'jdk-7u71-linux-x64.tar.gz':
        target          => $jh,
        fetch_options   => '-q -c --header "Cookie: oraclelicense=accept-securebackup-cookie"',
        url             => pick(fact('download_url'), 'http://download.oracle.com/otn-pub/java/jdk/7u71-b14/'),
        download_timout => 1800,
        strip           => true,
      } ->
      class { 'confluence':
        version             => '5.5.6',
        download_url        => fact('download_url'),
        javahome            => $jh,
      }
    EOS
    apply_manifest(pp, catch_failures: true)
    shell 'wget -q --tries=240 --retry-connrefused --read-timeout=10 localhost:8090', acceptable_exit_codes: [0]
    sleep 60
    shell 'wget -q --tries=240 --retry-connrefused --read-timeout=10 localhost:8090', acceptable_exit_codes: [0]
    sleep 30
    apply_manifest(pp, catch_changes: true)
  end

  describe process('java') do
    it { is_expected.to be_running }
  end

  describe port(8090) do
    it { is_expected.to be_listening }
  end

  describe service('confluence') do
    it { is_expected.to be_enabled }
  end

  describe user('confluence') do
    it { is_expected.to exist }
    it { is_expected.to belong_to_group 'confluence' }
    it { is_expected.to have_login_shell '/bin/true' }
  end

  describe command('wget -q --tries=240 --retry-connrefused --read-timeout=10 -O- localhost:8090') do
    its(:stdout) { is_expected.to match %r{http://www.atlassian.com/} }
  end
end
