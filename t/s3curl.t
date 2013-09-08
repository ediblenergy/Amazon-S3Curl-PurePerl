use strict;
use warnings FATAL => 'all';
use Test::More;
use Amazon::S3Curl::PurePerl;
use File::Temp;
my $file = File::Temp->new;
$file->autoflush(1);
die 'you need $ENV{AWS_ACCESS_KEY} and $ENV{AWS_SECRET_KEY}  and $ENV{S3_TEST_BUCKET} for the live tests.'
  unless $ENV{AWS_ACCESS_KEY} && $ENV{AWS_SECRET_KEY};
ok my $pp = Amazon::S3Curl::PurePerl->new(
    aws_access_key => $ENV{AWS_ACCESS_KEY},
    aws_secret_key => $ENV{AWS_SECRET_KEY},
    local_file     => "$file",
    url            => "/$ENV{S3_TEST_BUCKET}/testo"
  ),
  "Amazon::S3Curl::PurePerl instantiated";
ok $pp->download;
#my $test_string = "testo\ntesto2";
#print $file $test_string;
#ok $pp->upload;
#ok my $pp = Amazon::S3Curl::PurePerl->new(
#    aws_access_key => $ENV{AWS_ACCESS_KEY},
#    aws_secret_key => $ENV{AWS_SECRET_KEY},
#    local_file     => "$file",
#    url            => "/$ENV{S3_TEST_BUCKET}/"
#  ),
#  "Amazon::S3Curl::PurePerl instantiated";
#my $test_string = "testo\ntesto2";
#print $file $test_string;
#ok $pp->upload;
done_testing;
