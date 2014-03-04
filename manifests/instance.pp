class razor::instance (
  $target_os   = undef,
  $iso         = undef,
  $broker      = 'noop',
  $target_fqdn = undef,
)
{

  exec { 'razor create-broker':
    command => "/usr/local/bin/razor create-broker --name=${broker} --type=${broker}"
  }

  file { "/tmp/policy${::hostname}.json":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => 0644,
    content => template('razor/policy.json.erb'),
  }

  exec { 'razor create-policy':
    command => "/usr/local/bin/razor create-policy --json /tmp/policy${::hostname}.json",
    require => File["/tmp/policy${::hostname}.json"],
  }

  # TODO: automate repo creation.
  # razor -d create-repo --name=esx-5.5 --iso-url file:///tmp/VMware-VMvisor-Installer-5.5.0-1331820.x86_64.iso

}
