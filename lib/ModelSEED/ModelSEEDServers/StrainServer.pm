#===============================================================================
#
#         FILE:  StrainServer.pm
#
#  DESCRIPTION:  Implements additional helper functions neccesary to do
#                strain development.
#
#       AUTHOR:  Scott Devoid (sdevoid@gmail.com)
#===============================================================================

use strict;
use warnings;
use ModelSEED::FIGMODEL;

package ModelSEED::ModelSEEDServers::StrainServer;
use Data::Dumper;

sub new {
    my ($class) = @_;
    my $self;
    $self->{_figmodel} = ModelSEED::FIGMODEL->new();
	bless $self, $class;
    return $self;
}

sub figmodel { my ($self) = @_; return $self->{_figmodel}; }

sub methods {
    return [
    'getPrimers',
    'createStrain',
    'createInterval',
    'createPhenotype',
    'createMedia',
    ];
}

=head3 getPrimers

Arguments:
    genome => "genomeId",
    type  => "gene" || "coordinate",
    start => "peg.##" || "gene_alias" || "coordinate#",
    stop  =>  (as above)

Returns:
    {
        genes => [ list of genes in interval ],
        modelPredictions => [ list of predictions ],
        intersectingIntervals => [ list of interval ids ],
        primers => [ primers ], 
    }
=cut
sub getPrimers {
    my ($self, $args) = @_;
    print Dumper($args);    
    $args = $self->figmodel()->process_arguments($args,
        ['type', 'start', 'stop', 'genome']);
    my $rtv = {
        genes => [],
        modelPredictions => [],
        intersectingIntervals => [],
        primers => [],
    };
    my ($start, $stop);
    my $genome = $self->figmodel()->get_genome($args->{genome});
    if(!defined($genome)) {
        # error
        return;
    }
    my $features = $genome->feature_table(0); # don't get sequences
    if($args->{type} eq 'gene') {
        # convert genes to coordinates, always take the largest possible
        # interval so for genes A and B with two stops and two starts,
        # take the max and min two values
        my $startGene = $features->get_row_by_key($args->{start}, "ID"); 
        if(!defined($startGene)) {
            $startGene = $features->get_row_by_key($args->{start}, "ALIAS"); 
        } 
        my $stopGene = $features->get_row_by_key($args->{stop}, "ID"); 
        if(!defined($stopGene)) {
            $stopGene = $features->get_row_by_key($args->{stop}, "ALIAS"); 
        } 
        if(!defined($startGene) || !defined($stopGene)) {
            # error
            return;
        }
        $start = ($startGene->{"MIN LOCATION"}->[0] <  $stopGene->{"MIN LOCATION"}->[0]) ?
            $startGene->{"MIN LOCATION"}->[0] : $stopGene->{"MIN LOCATION"}->[0];
        $stop = ($startGene->{"MAX LOCATION"}->[0] <  $stopGene->{"MAX LOCATION"}->[0]) ?
            $startGene->{"MAX LOCATION"}->[0] : $stopGene->{"MAX LOCATION"}->[0];
    }
    # do primers (possibly updating boundaries) TODO
    $rtv->{primers} = ['AAAA', 'GGGG', 'TTTT', 'CCCC'];
    # get intervals
    my $contigs = $self->figmodel()->database()->get_objects('strContig');
    my $selected = [];
    foreach my $contig (@$contigs) {
        my $max = ($contig->stop() > $contig->start()) ? $contig->stop() : $contig->start();
        my $min = ($contig->stop() < $contig->start()) ? $contig->stop() : $contig->start();
        if($max <= $start && $min <= $stop) {
            push(@$selected, $contigs);
        }
    }
    $rtv->{intersectingIntervals} = [ map { $_->id() } @$selected ];
    # get genes
    for(my $i=0; $i<$features->size(); $i++) {
        my $feature = $features->get_row($i);
        if($feature->{"MAX LOCATION"}->[0] <= $start &&
            $feature->{"MIN LOCATION"}->[0] <= $stop) {
            push(@{$rtv->{genes}}, $feature->{ID}->[0]);
        }
    }
    # get predictions TODO
    return $rtv; 
}

=head3 createInterval
    Creates an interval
    Arguments:
        start => "coordinate",
        stop  => "coordinate",
        public => Boolean,
        id    => "string",
    Return :
        Hash with keys: start, stop, owner,
        public, id, creationDate, modificationDate
 
        OR
        
        Empty?
=cut
sub createInterval {
    my ($self, $args) = @_;    
    $args = $self->figmodel()->process_arguments($args,
        ['start', 'stop', 'public', 'id'], {}); 
    my $existing = $self->figmodel()->database()->get_object("strInt", { id => $args->{id} });
    $self->figmodel()->authenticate({ cgi => $self->cgi()});
    my $owner = $self->figmodel()->user();
    if(!defined($owner)) {
        return; # error!
    }
    if(defined($existing)) {
        return; # error!
    }
    my $hash = { start => $args->{start}, stop => $args->{stop},
        id => $args->{id}, public => $args->{public}, owner => $owner,
        creationDate => time(), modificationDate => time()};
    my $obj = $self->figmodel()->database()->create_object($hash);
    if(defined($obj)) {
        $hash = { map { $_ => $obj->$_() } keys %{$obj->attributes()} };
        delete $hash->{_id};
        return $hash;
    } else {
        return; # error!
    }
}

=head3 createStrain

    Arguments:
modificationDate
strainImplemented
parent
competance
EXPERIMENTER
lineage
creationDate
resistance
public
experimentDate
id
method
strainAttempted 
=cut
sub createStrain {
    my ($self, $args) = @_;    
}

sub createPhenotype {
    my ($self, $args) = @_;
}

sub createMedia {
    my ($self, $args) = @_;
}

1;
