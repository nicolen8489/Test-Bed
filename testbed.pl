#!/usr/bin/perl
$solver1;
$solver2;
$email;
$timeout;
@directories;
$outputfile;
$argPos = 0;

if($#ARGV < 1) {
  print "testbed.pl 'solver1' 'solver2' flags\n";
  print "Testbed flags: \n";
  print "-e email address to notify upon completion \n";
  print "-d directory of cnf files \n";
  print "-t timeout limit per cnf file \n";
  exit;
} else {
  use File::Basename;
  @timedata = localtime(time);
  $test = join "", $timedata[5]+1900, "_", $timedata[4], "_", $timedata[3], "-", $timedata[2], ":", $timedata[1], ":", $timedata[0];
  $outputfile = join "", ">output", $test, ".csv";
  open(OUTPUT, $outputfile);
  $solver1 = $ARGV[0];
  $solver2 = $ARGV[1];
  print OUTPUT ",",$solver1,",",$solver2,"\n";
  parseCommandLine();
  $numDirectories = @directories;
  if($numDirectories > 0) {
    foreach $directory (@directories) {
      processCnfDirectory($directory);
    }
  } else {
    print "At least one cnf directory must be passed to run.\n";
    exit;
  }
  close(OUTPUT);
#  emailOutput();
}

sub parseCommandLine() {
  for(my $i = 2; $i <= $#ARGV; $i++) {
    if ($ARGV[$i++] eq "-d") {
      push(@directories, $ARGV[$i]);
    } elsif ($ARGV[$i++] eq "-e") {
      $email = $ARGV[$i];
    } elsif ($ARGV[$i++] eq "-t") {
      $timeout = $ARGV[$i];
    }
  }
}

sub processCnfDirectory 
{
  use Time::HiRes(gettimeofday);
  use File::Basename;
  my($path) = @_;
  $didTimeout=0;
  local $SIG{ALRM} = sub { 
	die "Timeout\n";
        $didTimeout=1;
        print OUTPUT "timeout";
  };

  print( "working in: $path\n" );

  # append a trailing / if it's not there 
  $path .= '/' if($path !~ /\/$/); 

  # loop through the files contained in the directory 
  for my $file (glob($path . '*')) { 
    $timeout1=0;
    $timeout2=0; 

    # check if the file is a directory 
    if( -d $file)
    {
      # pass the directory to the routine ( recursion )
      processCnfDirectory($file);
    }
    elsif ($file =~ /.*\.cnf/)
    {
      print OUTPUT $file, ",";

      # run using the first solver
      $didTimeout=0;
      $start1=gettimeofday();
      alarm $timeout;
      $result = `$solver1 $file`;
      print $result;
#      $timeout1 = alarm 0;
      print "test ", $timeout1, "\n";
      $end1=gettimeofday();
      if($didTimeout == 0) {
        print OUTPUT $end1 - $start1;
      }
      print OUTPUT ",";
    
  
      # run using the second solver
      $didTimeout=0;
      $start2=gettimeofday();
      alarm $timeout;
      $result = `$solver2 $file`;
#      $timeout2 = alarm 0;
      $end2=gettimeofday();
      if($didTimeout == 0) {
        print OUTPUT $end2 - $start2;
      }

      print OUTPUT "\n";
    } 
  } 
}

#sub emailOutput() {
#  use Mail::Sender;
#  $sender = new Mail::Sender {
#      smtp => 'mail.yourISP.com',
#      from => 'nelson64@students.rowan.edu',
#      on_errors => undef,
#  };
#  $sender->OpenMultipart({to => 'Perl-Win32-Users@activeware.foo',
#                         subject => 'Mail::Sender.pm - new module'});
# (ref ($sender->MailFile(
#  {to =>'nicole.nelson8489@gmail.com', subject => 'Testbed run complete',
#   msg => "Your testbed run has completed. \n
#	Attached is the output csv file. \n
#	The file can also be found at $outputfile.",
#   file => $outputfile;
#  }));
#  and print "Mail sent OK."
# )
#}

sub emailOutput() {
  use Net::SMTP;
  $smtp = Net::SMTP->new('outlook.rowan.edu'); # connect to an SMTP server
  $smtp->mail('nelson64@students.rowan.edu');     # use the sender's address here
  $smtp->to('nicole.nelson8489@gmail.com');        # recipient's address
  $smtp->data();                      # Start the mail

  # Send the header.
  $smtp->datasend("To: nicole.nelson8489@gmail.com\n");
  $smtp->datasend("From: nelson64@students.rowan.edu\n");
  $smtp->datasend("\n");

  # Send the body.
  $smtp->datasend("Hello, World!\n");
  $smtp->dataend();                   # Finish sending the mail
  $smtp->quit;                        # Close the SMTP connection
}
