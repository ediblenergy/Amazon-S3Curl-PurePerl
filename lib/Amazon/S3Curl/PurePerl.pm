package Amazon::S3Curl::PurePerl;
use strict;
use warnings FATAL => 'all';
use Module::Runtime qw[ require_module ];

#For instances when you want to use s3, but don't want to install anything. ( and you have curl )
#Amazon S3 Authentication Tool for Curl
#Copyright 2006-2010 Amazon.com, Inc. or its affiliates. All Rights Reserved. 
use Moo;
use POSIX;
use File::Spec;
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
    ] )
{
    has $_ => (
        is       => 'ro',
        required => 1,
    );

}

has local_file => ( 
    is => 'ro',
    required => 1,
    predicate => 1,
);


sub _req {
    my ( $self, $method, $url ) = @_;
    die "method required" unless $method;
    $url ||= $self->url;
    my $resource = $url;
    my $to_sign  = $url;
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




sub download_cmd {
    my ($self) = @_;
    my $args = $self->_req('GET');
    push @$args, ( "-o", $self->local_file );
    return $args;
}

sub upload_cmd {
    my ($self) = @_;
    my $url = $self->url;
    #trailing slash for upload means curl will plop on the filename at the end, ruining the hash signature.
    if ( $url =~ m|/$| ) {
        my $file_name = ( File::Spec->splitpath( $self->local_file ) )[-1];
        $url .= $file_name;
    }
    my $args = $self->_req('PUT',$url);
    splice( @$args, $#$args, 0, "-T", $self->local_file );
    return $args;
}

sub delete_cmd {
    my $args = shift->_req('DELETE');
    splice( @$args, $#$args, 0, -X  => 'DELETE' );
    return $args;
}

sub _exec {
    my($self,$method) = @_;
    my $meth = $method."_cmd";
    die "cannot $meth" unless $self->can($meth);
    my $args = $self->$meth;
    log_info { "running " . join( " ", @_ ) } @$args;
    capture(@$args);
    return 1;
}

sub download {
    return shift->_exec("download");
}

sub upload {
    return shift->_exec("upload");
}

sub delete {
    return shift->_exec("delete");
}

sub _local_file_required {
    my $method = shift;
    sub {
        die "parameter local_file required for $method"
          unless shift->local_file;
    };
}

before download => _local_file_required('download');
before upload => _local_file_required('upload');
1;
