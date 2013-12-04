group { 'puppet': ensure => 'present' }
 
class sun_java_6 {
 
  $release = regsubst(generate("/usr/bin/lsb_release", "-s", "-c"), '(\w+)\s', '\1')
 
  # adds the partner repositry to apt
  file { "partner.list":
    path => "/etc/apt/sources.list.d/partner.list",
    ensure => file,
    owner => "root",
    group => "root",
    content => "deb http://archive.canonical.com/ $release partner\ndeb-src http://archive.canonical.com/ $release partner\n",
    notify => Exec["apt-get-update"],
  }
 
  exec { "apt-get-update":
    command => "/usr/bin/apt-get update",
    refreshonly => true,
  }
 
  package { "debconf-utils":
    ensure => installed
  }

  exec { 'accept-java-license':
    command => '/bin/echo /usr/bin/debconf shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections;/bin/echo /usr/bin/debconf shared/accepted-oracle-license-v1-1 seen true | sudo /usr/bin/debconf-set-selections;',
  } ->
  # finally install the package
  # oracle-java6-installer and oracle-java8-installer also available from the ppa
  package { 'oracle-java7-installer':
    ensure => present,
    require => [ File["partner.list"], Exec["accept-java-license"], Exec["apt-get-update"] ],
  }
 
 
}
#############################

################################################################################
# Definition: wget::fetch
#
# This class will download files from the internet.  You may define a web proxy
# using $http_proxy if necessary.
#
################################################################################
define wget::fetch (
  $destination,
  $source             = $title,
  $timeout            = '0',
  $verbose            = false,
  $redownload         = false,
  $nocheckcertificate = false,
  $execuser           = undef,
) {

  include wget

  # using "unless" with test instead of "creates" to re-attempt download
  # on empty files.
  # wget creates an empty file when a download fails, and then it wouldn't try
  # again to download the file
  if $::http_proxy {
    $environment = [ "HTTP_PROXY=${::http_proxy}", "http_proxy=${::http_proxy}" ]
  } else {
    $environment = []
  }

  $verbose_option = $verbose ? {
    true  => '--verbose',
    false => '--no-verbose'
  }

  $unless_test = $redownload ? {
    true  => 'test',
    false => "test -s ${destination}"
  }

  $nocheckcert_option = $nocheckcertificate ? {
    true  => ' --no-check-certificate',
    false => ''
  }

  exec { "wget-${name}":
    command     => "wget ${verbose_option}${nocheckcert_option} --output-document='${destination}' '${source}'",
    timeout     => $timeout,
    unless      => $unless_test,
    environment => $environment,
    user        => $execuser,
    path        => '/usr/bin:/usr/sbin:/bin:/usr/local/bin:/opt/local/bin',
    require     => Class['wget'],
  }
}
class wget (
  $version = present,
) {

  if $::operatingsystem != 'Darwin' {
    if ! defined(Package['wget']) {
      package { 'wget': ensure => $version }
    }
  }
}
#################################### install maven ###########################################

class maven(
  $version = '3.0.5',
  $repo = {
    #url      =>  'http://repo.maven.apache.org/maven2',#'http://repo1.maven.org/maven2',
    #username => '',
    #password => '',
  } ) {

  $archive = "/tmp/apache-maven-${version}-bin.tar.gz"

  # Avoid redownloading when tmp tar.gz is deleted
  if $::maven_version != $version {

    # we could use puppet-stdlib function !empty(repo) but avoiding adding a new
    # dependency for now
    if "x${repo['url']}x" != 'xx' {
      wget::authfetch { 'fetch-maven':
        source      => 'http://central.maven.org/maven2/org/apache/maven/apache-maven/3.0.5/apache-maven-3.0.5-bin.tar.gz',
#"${repo['url']}/org/apache/maven/apache-maven/$version/apache-maven-${version}-bin.tar.gz",
        destination => $archive,
        user        => $repo['username'],
        password    => $repo['password'],
        before      => Exec['maven-untar'],
      }
    } else {
      wget::fetch { 'fetch-maven':
        source      => 'http://archive.apache.org/dist/maven/binaries/apache-maven-3.0.5-bin.tar.gz',
        destination => $archive,
        before      => Exec['maven-untar'],
      }
    }
    exec { 'maven-untar':
      command => 'tar xzf /tmp/apache-maven-3.0.5-bin.tar.gz',
      cwd     => '/opt',
      creates => "/opt/apache-maven-${version}",
      path    => ['/bin','/usr/bin'],
    }

    file { '/usr/bin/mvn':
      ensure  => link,
      target  => "/opt/apache-maven-${version}/bin/mvn",
      require => Exec['maven-untar'],
    } ->
    file { '/usr/local/bin/mvn':
      ensure  => absent,
    }
  }
}

include wget
include sun_java_6
include maven
