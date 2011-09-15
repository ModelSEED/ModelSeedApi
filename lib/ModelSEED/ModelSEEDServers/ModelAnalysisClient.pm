
package ModelAnalysisClient;

#
# This is a SAS Component
#

use LWP::UserAgent;
use Data::Dumper;
use YAML::XS;

use strict;

sub new {
    my($class, $server_url) = @_;

    $server_url = 'http://bioseed.mcs.anl.gov/~chenry/FIG/CGI/ModelAnalysisServer.cgi' unless $server_url;

    my $self = {
		server_url => $server_url,
		ua => LWP::UserAgent->new(),
    };

    return bless $self, $class;
}

=head2 Primary Methods

=head3 submit_gene_activity_analysis
Definition:
	ModelAnalysisClient->submit_gene_activity_analysis();
Description:
	Receives an array of strings with data on gene activities in various media conditions specified based on gene expression data.
	Submits each column of gene activity data for analysis, and returns the number of jobs submitted as well as the ID for the jobs.
	This data is used to retreive the output from the runs.
Example input:
	("Model name;media A;media B;media C.....",
	"peg.1;0;0;1",
	"peg.2;0.3;0.1;0.5");
=cut
sub submit_gene_activity_analysis {
	my ($self, $filename) = @_;

	#Loading the file with the study data
	my $lines = $self->load_single_column_file($filename,"");
	#Submitting jobs to server
	my $result = $self->run_query("submit_gene_activity_analysis",(join("|",@{$lines})));
	my ($jobs,$jobid) = split(/\|/,$result);
	#Printing job data to file
	my $jobdata;
	if (-e "JobData.txt") {
		$jobdata = $self->load_single_column_file("JobData.txt","");
	} else {
		push(@{$jobdata},"Jobs;Job ID;Remaining jobs");
	}
	push(@{$jobdata},$jobs.";".$jobid.";".$jobs);
	$self->print_array_to_file("JobData.txt",$jobdata);
}

=head3 retreive_gene_activity_analysis
Definition:
	ModelAnalysisClient->retreive_gene_activity_analysis();
Description:
	Retrieves the results for any completed jobs on the server.
=cut
sub retreive_gene_activity_analysis {
	my ($self) = @_;

	#Loading the file with the study data
	my $lines = $self->load_single_column_file("JobData.txt","");
	#Submitting jobs to server
	my $result = $self->run_query("retreive_gene_activity_analysis",join("|",@{$lines}));
	if ($result eq "NO JOBS COMPLETE") {
		print "No jobs have been complete. Please check again later.\n";
		return;
	}

	my @results = split(/\|/,$result);
	#Printing job data to file
	my $allresults;
	if (-e "Output.txt") {
		$allresults = $self->load_single_column_file("Output.txt","");
	} else {
		push(@{$allresults},"Model ID;Media ID;Active genes;Inactive genes;Nuetral genes;Gene conflicts;Job ID;Job index");
	}
	#Counting the number of results for each job
	my $jobcount;
	for (my $i=0; $i < @results;$i++) {
		my $found = 0;
		for (my $j=0; $j < @{$allresults};$j++) {
			if ($allresults->[$j] eq $results[$i]) {
				$found = 1;
			}
		}
		if ($found == 0) {
			push(@{$allresults},$results[$i]);
			my @array = split(/;/,$results[$i]);
			if (!defined($jobcount->{$array[6]})) {
				$jobcount->{$array[6]} = 0;
			}
			$jobcount->{$array[6]}++
		}
	}
	#Adjusting the job data file based on completed jobs
	for (my $i=1; $i < @{$lines}; $i++) {
		my @array = split(/;/,$lines->[$i]);
		if (defined($jobcount->{$array[1]})) {
			$array[2] += -$jobcount->{$array[1]};
			if ($array[2] == 0) {
				splice(@{$lines},$i,1);
				$i--;
				next;
			}
		}
		$lines->[$i] = join(";",@array);
	}
	$lines->[0] = "Jobs;Job ID;Remaining jobs";
	$self->print_array_to_file("Output.txt",$allresults);
	$self->print_array_to_file("JobData.txt",$lines);
}

=head2 Internal Utility Methods

=head3 load_single_column_file
Definition:
	[string]:file lines = ModelAnalysisClient->load_single_column_file(string:filename,string:delimiter);
Description:
	Reads the specified file and returns a reference to an array of the lines in the file
=cut
sub load_single_column_file {
	my ($self,$Filename,$Delimiter) = @_;

	my $DataArrayRef = [];
	if (open (INPUT, "<$Filename")) {
		while (my $Line = <INPUT>) {
			chomp($Line);

			if (length($Delimiter) > 0) {
				my @Data = split(/$Delimiter/,$Line);
				$Line = $Data[0];
			}

			push(@{$DataArrayRef},$Line);
		}
		close(INPUT);
	} else {
		die "Cannot open $Filename: $!";
	}
	return $DataArrayRef;
}

=head3 print_array_to_file
Definition:
	FIGMODELdatabase->print_array_to_file(string::filename,[string::file lines],0/1::append);
Description:
	saving array to file
=cut
sub print_array_to_file {
	my ($self,$filename,$arrayRef,$Append) = @_;

	if (defined($Append) && $Append == 1) {
		open (OUTPUT, ">>$filename");
	} else {
		open (OUTPUT, ">$filename");
	}
	foreach my $Item (@{$arrayRef}) {
		if (length($Item) > 0) {
			print OUTPUT $Item."\n";
		}
	}
	close(OUTPUT);
}

=head3 run_query
Definition:
	? = ModelAnalysisClient->load_single_column_file(string:function,(string):arguments);
Description:
	Internal function handling the task of querying the server.
=cut
sub run_query {
    my($self, $function, @args ) = @_;

	my $arg_string = Dump(@args);

	my $form = [function => $function,
		args => "$arg_string"];

	my $res = $self->{ua}->post($self->{server_url}, $form);
	if ($res->is_success) {
		return Load($res->content);
	} else {
		die "error on post " . $res->content;
	}
}

1;
