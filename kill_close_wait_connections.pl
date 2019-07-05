#!/usr/bin/perl
# Pulled and Improvised from https://github.com/rghose/kill-close-wait-connections/blob/master/kill_close_wait_connections.pl

use strict;
use Socket;
use Net::RawIP;
use Net::Pcap;
use NetPacket::Ethernet qw(:strip);
use NetPacket::IP qw(:strip);
use NetPacket::TCP;
use POSIX qw(setsid);
use warnings;
use IO::File;

# Ensure last_close_wait_connections.log file exists
system("touch /tmp/last_close_wait_connections.log");
print "/tmp/last_close_wait_connections.log is touched.\n";

# Get current set of close wait connections in sorted order
system("netstat -tulnap | grep CLOSE_WAIT | sed -e 's/::ffff://g' | awk '{print \$4,\$5}' | sed 's/:/ /g' | sort > /tmp/current_close_wait_connections.log");
print "/tmp/current_close_wait_connections.log is prepared.\n";

# Log common lines into a file
system("comm -12 /tmp/last_close_wait_connections.log /tmp/current_close_wait_connections.log > /tmp/stale_close_wait_connections.log");
print "/tmp/stale_close_wait_connections.log is prepared.\n";

my $stale_close_wait_connections_file = "/tmp/stale_close_wait_connections.log";
if (!(-s $stale_close_wait_connections_file)){
    print "/tmp/stale_close_wait_connections.log seems to be empty. No much to do.\n";
}else{
    my $fh = IO::File->new( $stale_close_wait_connections_file, '<' ) or die "$stale_close_wait_connections_file: $!";
    while ( my $conn = <$fh> ) {
        chomp $conn;
        my ($src_ip, $src_port, $dst_ip, $dst_port) = split(' ', $conn);

        my $packet = Net::RawIP->new({
            ip => { frag_off => 0, tos => 0, saddr => $dst_ip, daddr => $src_ip },
            tcp => { dest => $src_port, source => $dst_port, seq => 10, ack => 1 }
        });
        $packet->send;
    }
    $fh->close();
    print "Finished ACKing all stale CLOSE_WAIT connections.\n";
}

# remove last_close_wait_connections.log file.
system("rm /tmp/last_close_wait_connections.log");
print "/tmp/last_close_wait_connections.log purged.\n";

# remove last_close_wait_connections.log file.
system("mv /tmp/current_close_wait_connections.log /tmp/last_close_wait_connections.log");
print "/tmp/current_close_wait_connections.log is renamed to /tmp/last_close_wait_connections.log.\n";
