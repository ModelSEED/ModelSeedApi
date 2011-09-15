#!/usr/bin/perl -w
use strict;

#
# Copyright (c) 2003-2006 University of Chicago and Fellowship
# for Interpretations of Genomes. All Rights Reserved.
#
# Primary author: Christopher Henry (chenry@mcs.anl.gov), Argonne National Laboratory
# Date of conception: 11/12/2008
#
# This file is part of the SEED Toolkit.
#
# The SEED Toolkit is free software. You can redistribute
# it and/or modify it under the terms of the SEED Toolkit
# Public License.
#
# You should have received a copy of the SEED Toolkit Public License
# along with this program; if not write to the University of Chicago
# at info@ci.uchicago.edu or the Fellowship for Interpretation of
# Genomes at veronika@thefig.info or download a copy from
# http://www.theseed.org/LICENSE.TXT.
#
package ModelAnalysisServer;

    use strict;
    use Tracer;
    use SeedUtils;
    use ServerThing;
    use FIGMODEL;

=head1 All model analysis access functions for this server

This file contains the functions and utilities used by the MODELanalysis Server
(B<MODEL_server.cgi>). The L</Primary Methods> represent function
calls direct to the server. These all have a signature similar to the following.

    my $document = $ModelAnalysisServerObject->function_name($args);

where C<$ModelAnalysisServerObject> is an object created by this module, C<$args> is a parameter
structure, and C<function_name> is the MODELanalysis Server function name. The
output is a structure.

=head2 Special Methods

=head3 new
Definition:
	ModelAnalysisServer::ModelAnalysisServer object = ModelAnalysisServer->new();
Description:
    Create a new ModelAnalysisServer function object.
	The server function object is used to invoke the server functions.
=cut
sub new {
    my ($class) = @_;
    my $ModelAnalysisServer;
	$ModelAnalysisServer->{_figmodel} = FIGMODEL->new();
	bless $ModelAnalysisServer, $class;
    return $ModelAnalysisServer;
}

sub figmodel {
    my ($self) = @_;
	return $self->{_figmodel};
}

=head2 Primary Methods

=head3 submit_gene_activity_analysis
Definition:
	(int::number of jobs successfully submitted,string::job indentifier) = ModelAnalysisServer->submit_gene_activity_analysis((string):array of gene call file lines);
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
	my ($self, $linedata) = @_;

    #Getting model and media data from first line
	my @lines = split(/\|/,$linedata);
	my @temp = split(/;/,$lines[0]);
	#checking that at least one column of data was submitted
	if (@temp < 2) {
		return (0,"ERROR:Less than two columns found in input data. Check input file");
	}
	#Retrieving model
	my $model = $self->figmodel()->get_model($temp[0]);
	if (!defined($model)) {
		return (0,"ERROR:".$temp[0]." model not found in database. Make sure model ID is listed in model viewer: http://www.theseed.org/models/");
	}
	#Checking that all specified media formulations exist
	my $MediaList;
	my $MediaHash;
	for (my $i=1; $i < @temp; $i++) {
		my $media = $self->figmodel()->database()->get_media($temp[$i]);
		if (defined($media)) {
			push(@{$MediaList},$temp[$i]);
			$MediaHash->{$temp[$i]}->{index} = $i;
		}
	}
	if (!defined($MediaList)) {
		return (0,"ERROR: No valid media formulations found.");
	}
	#Getting gene coefficients
	for (my $i=1; $i < @lines; $i++) {
		my @temp = split(/;/,$lines[$i]);
		my $gene = $temp[0];
		for (my $j=0; $j < @{$MediaList}; $j++) {
			my $coef = $temp[$MediaHash->{$MediaList->[$j]}->{index}];
			if (!defined($MediaHash->{$MediaList->[$j]}->{GeneActivityCall})) {
				$MediaHash->{$MediaList->[$j]}->{GeneActivityCall} = "";
			} else {
				$MediaHash->{$MediaList->[$j]}->{GeneActivityCall} .= "/";
			}
			$MediaHash->{$MediaList->[$j]}->{GeneActivityCall} .= $gene."_".$coef;
		}
	}
	#Adding microarray analysis jobs
	my $jobid = $self->figmodel()->filename();
	for (my $j=0; $j < @{$MediaList}; $j++) {
		$self->figmodel()->add_job_to_queue("run_microarray_analysis?".$model->id()."?".$MediaList->[$j]."?".$jobid."?".$j."?".$MediaHash->{$MediaList->[$j]}->{GeneActivityCall},"QSUB","cplex","MA-".$jobid);
	}

	my $result = @{$MediaList}."|".$jobid;
	return ($result);
}

=head3 retreive_gene_activity_analysis
Definition:
	ModelAnalysisClient->retreive_gene_activity_analysis();
Description:
	Retrieves the results for any completed jobs on the server.
=cut
sub retreive_gene_activity_analysis {
	my ($self,$linedata) = @_;

	#Checking on each job in the input
	my @lines = split(/\|/,$linedata);
	my $results;
	for (my $i=1; $i < @lines; $i++) {
		my @array = split(/;/,$lines[$i]);
		if (@array >= 2) {
			my $jobid = $array[1];
			my $jobnumber = $array[0];
			print STDERR $jobid." ".$jobnumber."\n";
			if (-d $self->figmodel()->config("MFAToolkit output directory")->[0].$jobid) {
				for (my $j=0; $j < $jobnumber; $j++) {
					print STDERR $jobid." ".$j."\n";
					if (-e $self->figmodel()->config("MFAToolkit output directory")->[0].$jobid."/MicroarrayOutput-".$j.".txt") {
						my $data = $self->figmodel()->database()->load_single_column_file($self->figmodel()->config("MFAToolkit output directory")->[0].$jobid."/MicroarrayOutput-".$j.".txt","");
						if (defined($data) && defined($data->[0])) {
							#system("rm ".$self->figmodel()->config("MFAToolkit output directory")->[0].$jobid."/MicroarrayOutput-".$j.".txt");
							push(@{$results},$data->[0]);
						}
					}
				}
			}
		}
	}
	if (!defined($results)) {
		return "NO JOBS COMPLETE";
	}
	return join("|",@{$results});
}

1;
