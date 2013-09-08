package Amazon::S3Curl::PurePerl;
use strict;
use warnings FATAL => 'all';
use Module::Runtime qw[ require_module ];
use Devel::SimpleTrace;
#ABSTRACT: Pure Perl s3 helper; generate params to pass to curl
#For instances when you want to use s3, but don't want to install anything. ( and you have curl )
use Moo;
use POSIX;
use Log::Contextual qw[ :log :dlog set_logger ];
use Log::Contextual::SimpleLogger;
use Digest::SHA::PurePerl;
use MIME::Base64 qw(encode_base64);
use IPC::System::Simple qw[ capture ];
use constant STAT_MODE => 2;
use constant STAT_UID  => 4;
our $DIGEST_HMAC;
BEGIN {
    eval {
        require_module("Digest::HMAC");
        $DIGEST_HMAC = "Digest::HMAC";
    };
    if ($@) {    #They dont have Digest::HMAC, use our packaged alternative
        $DIGEST_HMAC = "Amazon::S3Curl::PurePerl::Digest::HMAC";
        require_module($DIGEST_HMAC);
    }
};


set_logger(
    Log::Contextual::SimpleLogger->new(
        {
            levels_upto => 'debug'
        } ) );


has curl => (
    is      => 'ro',
    default => sub { 'curl' }    #maybe your curl isnt in path?
);

for (
    qw[
    aws_access_key
    aws_secret_key
    url
    local_file
    ] )
{
    has $_ => (
        is       => 'ro',
        required => 1,
    );

}

sub _req {
    my ( $self, $method ) = @_;
    $method ||= "GET";
    my $resource = $self->url;
    my $to_sign  = $self->url;
    $resource = "http://s3.amazonaws.com" . $resource;
    my $keyId       = $self->aws_access_key;
    my $httpDate    = POSIX::strftime( "%a, %d %b %Y %H:%M:%S +0000", gmtime );
    my $contentMD5  = "";
    my $contentType = "";
    my $xamzHeadersToSign = "";
    my $stringToSign      = join( "\n" =>
          ( $method, $contentMD5, $contentType, $httpDate, "$xamzHeadersToSign$to_sign" ) );
    my $hmac =
      $DIGEST_HMAC->new( $self->aws_secret_key, "Digest::SHA::PurePerl",
        64 );
    $hmac->add($stringToSign);
    my $signature = encode_base64( $hmac->digest, "" );
    return [
        $self->curl,
        -H => "Date: $httpDate",
        -H => "Authorization: AWS $keyId:$signature",
        -H => "content-type: $contentType",
        "-L",
        "-f",
        $resource,
    ];
}


sub download {
    my ($self) = @_;
    my $args = $self->_req('GET');
    push @$args, ( "-o", $self->local_file );
    log_info { "running: " . join( " ", @_ ) } @$args;
    capture(@$args);
    return $self->local_file;
}

sub upload {
    my ($self) = @_;
    my $args = $self->_req('PUT');
    splice( @$args, $#$args, 0, "-T", $self->local_file );
    log_info { "running: " . join( " ", @_ ) } @$args;
    capture(@$args);
    return $self->local_file;
}

1;
