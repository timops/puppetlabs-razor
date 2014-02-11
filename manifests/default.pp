$db_user = 'razor'
$db_password = 'razor'

$dhcp_iface = 'eth1'
$dhcp_ip = '10.127.1.10/24'
$dhcp_netmask = '255.255.255.0'
$dhcp_range = '10.127.1.100,10.127.1.150'
$dhcp_router = '10.127.1.1'

exec { '/usr/bin/apt-get -qy update': }

exec { "${dhcp_iface} configure":
    command => "/sbin/ifconfig ${dhcp_iface} ${dhcp_ip} netmask ${dhcp_netmask} up"
}
package { [ 'git', 'ruby', 'rubygems', 'dnsmasq' ]:
  ensure  => installed,
  require => Exec['/usr/bin/apt-get -qy update'],
}

# configure dnsmasq to serve dhcp, tftp, and dns caching/forwarding.
file { '/etc/dnsmasq.conf':
  ensure  => file,
  owner   => 'root',
  group   => 'root',
  mode    => 0644,
  content => template('razor/dnsmasq.conf.erb'),
  require => Package['dnsmasq'],
  notify  => Service['dnsmasq'],
}

file { '/var/lib/tftpboot':
  ensure => directory,
  owner  => 'root',
  group  => 'root',
  mode   => 0644,
}

file { '/var/lib/tftpboot/bootstrap.ipxe':
  ensure  => file,
  owner   => 'root',
  group   => 'root',
  mode    => 0644,
  content => template('razor/bootstrap.ipxe.erb'),
  require => File['/var/lib/tftpboot'],
}

service { 'dnsmasq':
  ensure  => running,
  require => [Package['dnsmasq'],File['/etc/dnsmasq.conf'],Exec["${dhcp_iface} configure"]],
}

file { '/var/lib/tftpboot/undionly.kpxe':
  ensure  => file,
  owner   => 'root',
  group   => 'root',
  mode    => 0644,
  source  => 'puppet:///modules/razor/undionly.kpxe',
  require => File['/var/lib/tftpboot'],
}

class { 'postgresql::server': } ->

# create required role for razor.
postgresql::server::role { $db_user:
  password_hash => postgresql_password($db_user, $db_password),
} ->

# create required razor databases.
postgresql::server::db { [ 'razor_test', 'razor_dev', 'razor_prd' ]:
  user     => $db_user,
  password => postgresql_password($db_user, $db_password),
} ->

# deploy razor using previously created role/databases.
class { 'razor':
  libarchive  => [ 'libarchive12', 'libarchive-dev' ],
  tftp        => false,
  db_user     => $db_user,
  db_password => $db_password,
} ->

# overlay the custom ESXi deployment template on existing razor server install.
file { '/opt/razor/tasks/vmware_esxi/ks.cfg.erb':
  ensure  => file,
  owner   => 'razor-server',
  group   => 'razor-server',
  mode    => 0644,
  source  => 'puppet:///modules/razor/ks.cfg.erb',
  require => Class['razor::server'],
}

package { 'razor-client':
  ensure   => installed,
  provider => gem,
  require  => Package['rubygems'],
}
