use strict;
use warnings FATAL => 'all';
use Test::More;
use Amazon::S3Curl::PurePerl;
use File::Temp;
use File::Spec;

my $download_file = File::Temp->new;
my $upload_file = File::Temp->new;
$upload_file->autoflush(1);
die 'you need $ENV{AWS_ACCESS_KEY} and $ENV{AWS_SECRET_KEY}  and $ENV{S3_TEST_BUCKET} for the live tests.'
  unless $ENV{AWS_ACCESS_KEY} && $ENV{AWS_SECRET_KEY};

my $filename = (File::Spec->splitpath($upload_file))[-1];

my $test_string = "testo\ntesto2";
print $upload_file $test_string;

my %pp_args = (
    aws_access_key => $ENV{AWS_ACCESS_KEY},
    aws_secret_key => $ENV{AWS_SECRET_KEY},
    local_file     => "$upload_file",
    url            => "/$ENV{S3_TEST_BUCKET}/$filename"
);

ok my $uploader = Amazon::S3Curl::PurePerl->new(%pp_args),
  "instantiated uploader";

ok $uploader->upload, "uploaded file";

ok my $downloader = Amazon::S3Curl::PurePerl->new(
    %pp_args, 
    local_file => "$download_file"
  ),
  "Amazon::S3Curl::PurePerl instantiated";
ok $downloader->download;
{
    local $/ = undef;
    open(my $fh_left, "<", $download_file ) or die "$@ $!";
    open(my $fh_right, "<", $upload_file) or die "$@ $!";
    my $str = <$fh_left>;
    my $str2 = <$fh_right>;
    is( $str, $str2, "downloaded file matches uploaded file" );
};

ok $downloader->delete, "delete remote file";

ok my $should_die = Amazon::S3Curl::PurePerl->new(%pp_args, local_file => undef );
eval {
    $should_die->download;
    fail "should've died";
};
ok $@, "died without local_file param.";

done_testing;
