#===============================================================================
#
#         FILE:  ModelImportServer.pm
#
#  DESCRIPTION:  This server contains one function that allows users to import
#                models via tab-delimited files or an sbml file into the model-seed.
#                There is a single function that they may repeatedly call, which
#                will guide them along the path to importing a complete model.
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Scott Devoid
#      COMPANY:  University of Chicago, Computation Institute
#      VERSION:  1.0
#      CREATED:  02/07/11 14:10:52
#     REVISION:  ---
#===============================================================================
use ModelSEED::FIGMODEL;
use strict;
use warnings;
use File::Temp;
use XML::LibXML;
use URI::Escape;
use Data::Dumper;
use CGI;

package ModelSEED::ModelSEEDServers::ModelImportServer;

sub new {
    my ($class) = @_;
    my $self = {};
    $self->{_figmodel} = ModelSEED::FIGMODEL->new();
    $self->{_current_node_type} = "";
    $self->{_compartment_index} = ();
    bless $self;
    $self->init_search_indicies();
    return $self;
}

sub figmodel {
    my ($self) = @_;
    return $self->{_figmodel};
}

sub methods {
    return [ 'check_id',
             'stat',
             'import',
             'uploadFile',
    ];
}

sub init_search_indicies {
    my ($self) = @_;
    $self->add_index('cpd_name', $self->init_hashlist_on_db_object('cpdals', {'type' => 'searchname'}, 'alias', 'COMPOUND'),
        ['compound_name', 'cpdals_searchname', '_cpd_identity', 'cpd_attr']);
    $self->add_index('cpd_id_to_name', $self->init_hashlist_on_db_object('cpdals', {'type' => 'name'}, 'COMPOUND', 'alias'),
        ['_cpd_helper', 'cpd_attr']);
    $self->add_index('cpd_KEGG', $self->init_hashlist_on_db_object('cpdals', {'type' => 'KEGG'}, 'alias', 'COMPOUND'),
        ['cpdals_KEGG', '_cpd_identity']);
    $self->add_index('cpd_SEED', $self->init_hashlist_on_db_object('compound', {}, 'id', 'id'),
        ['_cpd_identity']);
    $self->add_index('cpd_formula', $self->init_hashlist_on_db_object('compound', {}, 'formula', 'id'), ['cpd_info', 'cpd_attr']);
    my $formulaMatcher = sub {
        my $index = shift;
        my $value = shift;
        if ($value =~ /^([A-Z][a-z]{0,1}\d*)+$/) {
            return [$value];
        } else {
            return [];
        }
    };
    $self->add_index('rxn_SEED', $self->init_hashlist_on_db_object('reaction', {}, 'id', 'id'),
        ['_rxn_other']);
    $self->add_index('rxn_equation', $self->init_hashlist_on_db_object('reaction', {}, 'code', 'id'),
        ['reaction_code', '_rxn_identity']);
    $self->add_index('rxn_KEGG', $self->init_hashlist_on_db_object('rxnals', {'type' => 'KEGG'}, 'alias', 'REACTION'),
        ['_rxn_other']);

    #Subroutines for lookup() function
    my $searchName = sub {
        my $b = shift;
        my $a = shift;
        my @vs = $self->figmodel()->convert_to_search_name($a);
        foreach my $v (@vs) {
            if(defined($b->{$v})) {
                return $b->{$v}; # < list
            }
        }
	
	#Look to see if names and ids are appended with compartment ids
	#Seaver 07/01/11

	foreach my $cmpt (keys %{$self->{_compartment_index}}){
	    my $len=length($cmpt);
	    my $found="";
	    if(substr($a,-$len) eq $cmpt){
		$found = substr($a,0,-$len-1);
		@vs = $self->figmodel()->convert_to_search_name($found);
		foreach my $v (@vs) {
		    if(defined($b->{$v})) {
			return $b->{$v}; # < list
		    }
		}
	    }
	    if(substr($a,0,$len) eq $cmpt){
		$found = substr($a,$len+1,length($a));
		@vs = $self->figmodel()->convert_to_search_name($found);
		foreach my $v (@vs) {
		    if(defined($b->{$v})) {
			return $b->{$v}; # < list
		    }
		}
	    }
	}
	
	#Look to see if multiple names are split by ';'
	#Seaver 07/01/11

	my @values=split /;/,$a;
	foreach my $value(@values){
	    @vs = $self->figmodel()->convert_to_search_name($value);
	    foreach my $v (@vs) {
		if(defined($b->{$v})) {
		    return $b->{$v}; # < list
		}
	    }
	}

        return []; 
    };
    $self->index_subroutines('cpd_name', $searchName);
    my $stripCpdIdCompartments = sub {
        my $index = shift;
        my $value = shift;
        $value =~ s/(\[.\])|(_.+?$)//;

        if(defined($index->{$value})) {
            return $index->{$value}; # < list
        } else {
            return [];
        }
    };
    $self->index_subroutines('cpd_SEED', $stripCpdIdCompartments);
    my $find_KEGG_cpd_id = sub {
	my $index = shift;
	my $value = shift;

	#Searching for KEGG IDs found in CM and LN models
	#Seaver 06/06/11

	$_ = $value;
	my @OriginalArray = /(C\d{5})/g;
	for (my $i=0; $i < @OriginalArray; $i++) {
	    if(defined($index->{$OriginalArray[$i]})){
		return $index->{$OriginalArray[$i]};
	    }
	}
	return [];
    };
    $self->index_subroutines('cpd_KEGG',$find_KEGG_cpd_id);
    my $find_KEGG_rxn_id = sub {
	my $index = shift;
	my $value = shift;

	#Searching for KEGG IDs found in CM and LN models
	#Seaver 06/06/11

	$_ = $value;
	my @OriginalArray = /(R\d{5})/g;
	for (my $i=0; $i < @OriginalArray; $i++) {
	    if(defined($index->{$OriginalArray[$i]})){
		return $index->{$OriginalArray[$i]};
	    }
	}
	return [];
    };
    $self->index_subroutines('rxn_KEGG',$find_KEGG_rxn_id);
    my $equationCodeConverter = sub {
        my $index = shift;
        my $value = shift;
        my $rxn_cpd_idxs = $self->get_index('rxn_cpd_equation');
        if(defined($rxn_cpd_idxs)) {
            my ($dir, $code, $revCode, $eq, $compartment, $error) =
                $self->figmodel()->ConvertEquationToCode($value, $rxn_cpd_idxs);
            return undef if ($error);

            if(defined($index->{$code})) {
                return $index->{$code}; # < list
            } elsif(defined($revCode) && defined($index->{$revCode})) {
                return $index->{$revCode}; # < list
            } else {
                return [];
            }
        } 

        my ($dir, $code, $revCode, $eq, $compartment, $error) =
            $self->figmodel()->ConvertEquationToCode($value, {});
        return undef if($error);
        if(defined($index->{$code})) {
            return $index->{$code}; # < list
        } elsif(defined($index->{$revCode})) {
            return $index->{$revCode}; # < list
        } else {
            return [];
        } 
    };
    $self->index_subroutines('rxn_equation', $equationCodeConverter); 
} 

sub add_index {
    my ($self, $id, $index, $classes, $compareSubroutine) = @_;
    if(defined($self->get_index($id))) {
        warn "Index with name $id already exists!";
    } else {
        $self->{_index_list}->{$id} = $index;
    }
    if(defined($classes)) {
        foreach my $class (@$classes) {
            if(not defined($self->{_index_class_list}->{$class})) {
                $self->{_index_class_list}->{$class} = [$id];
            } else {
                push(@{$self->{_index_class_list}->{$class}}, $id);
            }
        }
    }
}

# A routine takes index, value and returns [values]  || []
sub index_subroutines {
    my ($self, $index, $routine) = @_;
    if(defined($routine)) {
        $self->{_index_subroutine_list} = {} unless(defined($self->{_index_subroutine_list}));
        $self->{_index_subroutine_list}->{$index} = [] unless(defined($self->{_index_subroutine_list}->{$index}));
        push(@{$self->{_index_subroutine_list}->{$index}}, $routine);
    }
    if(defined($self->{_index_subroutine_list}) &&
        defined($self->{_index_subroutine_list}->{$index})) {
        return $self->{_index_subroutine_list}->{$index};
    } else {
        return [];
    }
}
    
sub get_class_index {
    my ($self, $class) = @_;
    if(defined($self->{_index_class_list}->{$class})) {
        return  $self->{_index_class_list}->{$class};
    } else {
        return [];
    }
}
    
sub get_index {
    my ($self, $id) = @_;
    if(defined($id) && defined($self->{_index_list}->{$id})) {
        return $self->{_index_list}->{$id};
    } elsif(defined($id)) {
        return undef;
    } else {
        my @keys = keys %{$self->{_index_list}};
        return \@keys;
    }
}

sub lookup {
    my ($self, $type, $value) = @_;
    my $index = $self->get_index($type);
    my $r = [];
    
    if($type ne "_rxn_cpd_map"){
	return $r if($self->{_current_node_type} eq "species" && substr($type,0,index($type,'_')) ne "cpd");
	return $r if($self->{_current_node_type} eq "reaction" && substr($type,0,index($type,'_')) ne "rxn");
    }
    return $r if(not defined($index));

    if(defined($index->{$value})) {
	push(@$r, @{$index->{$value}});
    } elsif(defined(my $routines = $self->index_subroutines($type))) {
        foreach my $routine (@$routines) {
            my $val;
            if(defined($val = &$routine($index, $value))) {
                push(@$r, @$val);
            }
        }
    }
    return $r;
}
    
sub init_hashlist_on_db_object {
    my ($self, $type, $selectCriteria, $keyAttr, $valAttr) = @_;
    my $hashList = {};
    my $objects = $self->figmodel()->database()->get_objects($type, $selectCriteria);
    foreach my $object (@$objects) {
        if(defined($object->$keyAttr()) && defined($object->$valAttr())) {
            $hashList->{$object->$keyAttr()} = [] unless(defined($hashList->{$object->$keyAttr()}));
            push(@{$hashList->{$object->$keyAttr()}}, $object->$valAttr());
        }
    }
    return $hashList;
}

# Structure of Request parameters:
# 1. check_id
# 2. uplaod files
# 3. check_parse_status
# 4. submit


sub stat {
    my ($self, $args) = @_;
    my $retObject =  {"success" => "0", "error" => "1", "msg" =>
                  "Unable to find file(s), try uploading them again?" };
    # check if logged in
    if(defined($self->{cgi})) {
        $self->figmodel()->authenticate({cgi => $self->{cgi}});
    } elsif(defined($args->{username}) && defined($args->{password})) {
        $self->figmodel()->authenticate({username => $args->{username},
                                         password => $args->{password}});
    } 
    my $owner = $self->figmodel()->user(); 
    unless(defined($owner) && $owner ne 'PUBLIC')  {
        $retObject->{'msg'} = "You must login to import a model";
        return $retObject;
    }
    # check if model name and id are provided
    unless(defined($args->{name}) && defined($args->{id})) {
        $retObject->{'msg'} = "You must provide a model id and name!";
        return $retObject;
    } 
    # check if model already taken by someone else
    my $modelHash = $self->model_info_setter($args->{id});
    if(ref($modelHash) ne 'HASH' && $modelHash->owner() ne $owner) {
        $retObject->{'msg'} = "Model with that id already exists!";
        return  $retObject;
    }
    # now initialize the model in the database with placeholder
    $modelHash->{'name'} = $args->{name};
    $modelHash->{'id'} = $args->{id};
    $modelHash->{'status'} = "Model ID reserved; model not yet imported";
    my ($compoundFile, $reactionFile) = undef;
    if(defined($args->{sbmlt})) {
        $compoundFile = $self->get_file($args->{sbmlt});
        $reactionFile = $self->get_file($args->{sbmlt});
    } elsif(defined($args->{rxnt}) && $args->{cpdt}) {
        $compoundFile = $self->get_file($args->{cpdt});
        $reactionFile = $self->get_file($args->{rxnt});
    }
    
    if(not defined($reactionFile)) {
        $retObject->{'msg'} = "Unable to find the file; try uploading again?";
        return $retObject;
    }
    my $labels = $self->get_labels($reactionFile, $compoundFile); 
    my ($foundCompounds, $notFoundCompounds) = $self->bin_compounds($compoundFile, $labels);
    $retObject->{'compounds'}->{'missed'} = $notFoundCompounds;
    $retObject->{'compounds'}->{'matched'} = $foundCompounds;
    my $reaction_compound_map = $self->make_reaction_compound_map($foundCompounds, $labels);
    $self->add_index('rxn_cpd_equation', $reaction_compound_map, ['rxn_cpd_equation']);
    my ($foundReactions, $notFoundReactions) = $self->bin_reactions($reactionFile, $labels);
    $retObject->{'reactions'}->{'missed'} = $notFoundReactions;
    $retObject->{'reactions'}->{'matched'} = $foundReactions;
    foreach my $arg ('compounds', 'reactions') {
        $retObject->{$arg}->{'missed'} = scalar(@{$retObject->{$arg}->{'missed'}});
        my $count = 0;
        foreach my $id (keys %{$retObject->{$arg}->{'matched'}}) {
            $count += scalar(@{$retObject->{$arg}->{'matched'}->{$id}});
        }
        $retObject->{$arg}->{'matched'} = $count;
    }
    $retObject->{'msg'} = "Previewing imported model";
    $retObject->{'eror'} = '0';
    $retObject->{'success'} = '1';
    return $retObject;
}

# Takes:
#   id => ""
# Returns:
#   msg => "",
#   success => bool
#   error   => bool
sub check_id {
    my ($self, $args) = @_;
    my $id = $args->{'id'};
    unless(defined($id)) {
        return {"msg" => "", "success" => "false", "error" => "true"};
    }
    my $escape = URI::Escape::uri_escape($id);
    if($id ne $escape) {
        return {"msg" => "Id must only contain letters and numbers", "success" => "false", "error" => "false"};
    }
    my $modelsWithId = $self->figmodel()->database()->get_objects('model', {'id' => $id});
    if(defined($modelsWithId) && @$modelsWithId > 0) {
        return {"msg" => "Model id has already been taken", "success" => "false", "error" => "true"};
    } else {
        return {"msg" => "Available!", "success" => "true", "error" => "false" };
    }
}

sub uploadFile {
    my ($self, $args) = @_;
    my $cgi = $self->{cgi};
    my $uploadPath = "/vol/model-dev/MODEL_DEV_DB/tmp/";
    my $upload = $cgi->upload('Filedata');
    if(defined($upload)) {
        my $fh = $upload;
        my ($save_fh, $save_name) = File::Temp::tempfile('model-rxnf-XXXXXXXX', DIR => $uploadPath);
        my ($bytes, $buff);
        while(<$fh>) {
            print $save_fh $_;
        }
        close($save_fh);
        $save_name =~ s/$uploadPath//;
        $save_name =~ s/model-rxnf-//;
        return { 'file_token' => $save_name };
    }
}

sub createCompounds {
    my ($self, $compoundObjectArray, $owner, $scope, $typePaths) = @_;
    my $cpdStatus = {};
    my $cpd_attr_types = $self->get_class_index('cpd_attr'); 
    foreach my $obj (@$compoundObjectArray) {
        my $objId = undef;
        my $labels  = $self->get_class_index('_rxn_cpd_map');
        foreach my $label (@$labels) {
            my $value = $self->get_value_by_label($typePaths, $obj, $label);
            if(defined($value)) {
                $objId = $value;
                last;
            }
        }
        $cpdStatus->{$objId} = 0; 
        my $path = $self->follow_path($typePaths->{'cpd_name'}, $obj);
        my $cpdHash = { 'id' => '',
                        'name' => '', 'abbrev' => '', 'formula' => '',
                        'mass' => '', 'charge'  => '', 'deltaG'  => '',
                        'deltaGErr' => '', "structuralCues" => "", "stringcode" => "", 
                        "pKa" => "", "pKb" => "", "owner" => $owner, "scope" => $scope,
                        "modificationDate" => time(), "creationDate" => time(),
                        "public" => "1" };
        foreach my $type (@$cpd_attr_types) {
            my $attrName = $type;
            $attrName =~ s/cpd//; # e.g. cpdformula -> formula
            if(defined($typePaths->{$type}) && defined($cpdHash->{$attrName})) {
                my $value = $self->get_value_by_label($typePaths, $obj, $type);
                if(defined($value)) {
                    $cpdHash->{$attrName} = $value;
                    warn "Setting $value for attr $attrName on object $objId \n";
                }
            }
        }
        if(defined($cpdHash->{'name'})) {
            $cpdHash->{'name'} = substr($cpdHash->{'name'}, 0, 255);
            $cpdHash->{'abbrev'} = $cpdHash->{'name'};
        }          

        $cpdHash->{'owner'} = $owner;
        $cpdHash->{'scope'} = $scope;               
        $cpdHash->{'id'} = $self->figmodel()->database()->check_out_new_id('compound');
        $objId = $cpdHash->{'id'};
        my $compound = $self->figmodel()->database()->create_object('compound', $cpdHash);
        if(defined($compound)) {
            $cpdStatus->{$objId} = $compound->id(); 
        } else {
            $cpdStatus->{$objId} = 0;
        }
    }
    my $cpds = [];
    foreach my $id (values %$cpdStatus) {
        if($id =~ /cpd\d\d\d\d\d/) {
            push(@$cpds, $id);
        }
    }
    warn "Created compounds: " . join(' ', @$cpds) . "\n";
    if(@$cpds > 0) {
        #$self->figmodel()->database()->updateCompoundFilesFromDb($cpds);
        #$self->figmodel()->database()->ProcessDatabaseWithMFAToolkit($cpds);    
        #$self->figmodel()->database()->updateCompoundDbFromFiles($cpds);
    }
    return $cpdStatus;
}

sub createReactions {
    my ($self, $reactionObjectArray, $owner, $scope, $typePaths) = @_;
    my $rxnStatus = {};
    my $rxn_attr_types = $self->get_class_index('rxn_attr'); 
    foreach my $obj (@$reactionObjectArray) {
        my $labels = $self->get_class_index('_rxn_cpd_map');

        my $objId = $self->follow_path($typePaths->{'rxn_name'}, $obj);
        if(not defined($objId)) {
            $objId = $obj->nodePath();
        }
        my $rxnHash = { "id" => '',  "name" => '',  "abbrev" => '',
                        "enzyme" => '', "code" => undef, "equation"=> undef,
                        "definition" => undef, "deltaG" => '', "deltaGErr" => '',
                        "structuralCues" => '', "reversibility" => '',
                        "thermoReversibility" => '', "owner" => '',
                        "scope" => '', "modificationDate" => time(),
                        "creationDate" => time(), "public" => 1,
                        "status" => 1, "transportedAtoms" => '' };
        foreach my $type (@$rxn_attr_types) {
            my $attrName = $type;
            $attrName =~ s/rxn//; # e.g. cpdformula -> formula
            if(defined($typePaths->{$type}) && defined($rxnHash->{$attrName})) {
                my $value = $self->get_value_by_label($typePaths, $obj, $type);
                if(defined($value)) {
                    $rxnHash->{$attrName} = $value;
                }
            }
        }
        # Reaction equation is a bit tricky
        my ($eq, $code, $equation, $definition, $dir, $compartment) = undef;
        if(ref($obj) ne 'ARRAY') {
           $eq = $self->figmodel()->sbml_2_reaction($obj);
        } else {
            my $eqPaths = $typePaths->{'rxn_equation'};
            $eq = $self->follow_path($eqPaths->[0], $obj);
        }
        warn "Got equation: " . join(' ', @$eq) . "\n";
        ($code, $equation, $definition, $dir, $compartment) = $self->eq_to_stuff($eq);
        $rxnHash->{'code'} = $code;
        $rxnHash->{'equation'} = $equation;
        $rxnHash->{'definition'} = $definition;
        if(defined($rxnHash->{'name'})) {
            $rxnHash->{'name'} = substr($rxnHash->{'name'}, 0, 255);
            $rxnHash->{'abbrev'} = $rxnHash->{'name'};
        }
        $rxnHash->{'owner'} = $owner;
        $rxnHash->{'scope'} = $scope;               
        $rxnHash->{'id'} = $self->figmodel()->database()->check_out_new_id('reaction');
        my $reaction = $self->figmodel()->database()->create_object('reaction', $rxnHash);
        if(defined($reaction)) {
            $rxnStatus->{$objId} = $reaction->id(); 
        }
        $self->createCompoundReaction($equation, $compartment, $reaction->id());
        $self->createReactionModel($obj, $typePaths, $reaction->id(), $scope);
    }
    my $rxns = [];
    foreach my $id (values %$rxnStatus) {
        if($id =~ /rxn\d+/) {
            push(@$rxns, $id);
        }
    }
    warn "Created reactions: " . join(' ', @$rxns) . "\n";
    #$self->figmodel()->database()->updateReactionFilesFromDb($rxns);
    #$self->figmodel()->database()->ProcessDatabaseWithMFAToolkit($rxns);    
    #$self->figmodel()->database()->updateReactionDbFromFiles($rxns);
    return $rxnStatus;
}

sub createCompoundReaction {
    my ($self, $equation, $rxnCompartment, $reactionId) = @_;
    my $compounds = [];
    my $lhsCpds = {};
    my $rhsCpds = {};
    my $side = 0;
    my @parts = split(/\s/, $equation);
    foreach my $part (@parts) {
        if($part =~ /<=>/) {
            $side = 1;
        } elsif($part =~ /(cpd\d\d\d\d\d)/ && $side == 0) {
            $lhsCpds->{$1} = 1;
        } elsif($part =~ /(cpd\d\d\d\d\d)/ && $side == 1) {
            $rhsCpds->{$1} = 1;
        }
    }
    while ($equation =~ m/(\(\d+\)){0,1} (cpd\d\d\d\d\d)(\[.\]){0,1}/g) {
        my $count = $1 || '(1)';
        my $compound = $2;
        my $compartment = $3 || $rxnCompartment;
        $count =~ s/[\)\(]//g;
        if(defined($lhsCpds->{$compound})) {
            $count = '-'.$count; 
        }
        $compartment =~ s/[\]\[]//g;
        push(@$compounds, {'compound' => $compound, 'count' => $count, 'compartment' => $compartment});
    }
    foreach my $compound (@$compounds) {
        my $hash = { 'COMPOUND' => $compound->{'compound'},
                     'REACTION' => $reactionId,
                     'coefficient' => $compound->{'count'},
                     'compartment' => $compound->{'compartment'},
                     'cofactor' => 0 };
        $self->figmodel()->database()->create_object('cpdrxn', $hash);
    }
}

sub createReactionModel {
    my ($self, $obj, $typePaths, $reactionId, $modelId) = @_;
    my $eq;
    if(ref($obj) eq 'ARRAY') {
        $eq = $self->figmodel()->sbml_2_reaction($obj);
    } else {
        my $eqPaths = $typePaths->{'rxn_equation'};
        $eq = $self->follow_path($eqPaths->[0], $obj);
    }
    my ($code, $equation, $definition, $dir, $compartment) = $self->eq_to_stuff($eq);
    $self->figmodel()->database()->create_object('rxnmdl', { 'REACTION' => $reactionId,
        'MODEL' => $modelId, 'directionality' => $dir,
        'compartment' => $compartment, 'pegs' => ''});
    return;
}

sub import {
    my ($self, $args) = @_;
    my $retObject =  {"success" => "0", "error" => "1", "msg" =>
                  "Unable to find file(s), try uploading them again?" };
    # check if logged in
#    $self->figmodel()->authenticate({cgi => $self->{cgi}});
#    my $owner = $self->figmodel()->user(); 
#    unless(defined($owner) && $owner ne 'PUBLIC')  {
#        $retObject->{'msg'} = "You must login to import a model";
#        return $retObject;
#    }
#    # check if model name and id are provided
#    unless(defined($args->{name}) && defined($args->{id})) {
#        $retObject->{'msg'} = "You must provide a model id and name!";
#        return $retObject;
#    } 
#    # check if model already taken by someone else
#    my $modelHash = $self->model_info_setter($args->{id});
#    if(ref($modelHash) ne 'HASH') {
#        $retObject->{'msg'} = "Model with that id already exists!";
#        return  $retObject;
#    }
#    # now initialize the model in the database with placeholder
#    $self->figmodel()->createNewModel({-runPreliminaryReconstruction => 0,
#                                       -id => $args->{id},
#                                       -owner => $owner,
#                                      });
#    my $model = $self->figmodel()->get_model($args->{id});
#    unless(defined($model)) {
#        $retObject->{'msg'} = "Unknown error in initializing model.";
#    }
#    $model->message("Model ID reserved; model not yet imported");
#    $model->name($args->{name});
#    my ($compoundFile, $reactionFile) = undef;
#    if(defined($args->{sbmlt})) {
#        $compoundFile = $self->get_file($args->{sbmlt});
#        $reactionFile = $self->get_file($args->{sbmlt});
#    } elsif(defined($args->{rxnt}) && $args->{cpdt}) {
#        $compoundFile = $self->get_file($args->{cpdt});
#        $reactionFile = $self->get_file($args->{rxnt});
#    }
#    
#    if(not defined($reactionFile)) {
#        $retObject->{'msg'} = "Unable to find the file; try uploading again?";
#        return $retObject;
#    }
#    my $labels = $self->get_labels($reactionFile, $compoundFile); 
#    my ($foundCompounds, $notFoundCompounds) = $self->bin_compounds($compoundFile, $labels);
#    # Now create not found compounds, add tehm to the reaction_compound_equation index
#    my $compoundStatus = $self->createCompounds($notFoundCompounds, $model->owner(), $model->id(), $labels);
#    # Create index from model compound Ids to seed compound Ids
#    my $reaction_compound_map = $self->make_reaction_compound_map($foundCompounds, $labels);
#    # Add the ids from newly created compounds to that index
#    foreach my $rxn_cpd (keys %$compoundStatus) {
#        if($compoundStatus->{$rxn_cpd} ne '0') {
#            $reaction_compound_map->{$rxn_cpd} = [] unless(defined($reaction_compound_map->{$rxn_cpd}));
#            push(@{$reaction_compound_map->{$rxn_cpd}}, $compoundStatus->{$rxn_cpd});
#        } else {
#            warn "unable to create compound for " . $rxn_cpd;
#        }
#    }
#    $self->add_index('reaction_compound_equation', $reaction_compound_map, ['reaction_compound_equation']);
#    my ($foundReactions, $notFoundReactions) = $self->bin_reactions($reactionFile, $labels);
#    # Now crate reactions, this also creates the rxnmdl links
#    my $reactionStatus = $self->createReactions($notFoundReactions, $model->owner(), $model->id(), $labels);
#    # Crate reaction model links for found reactions
#    my $count = 0; # number of model reactions that reduced into a single seed rxn
#    foreach my $seedRxn (keys %$foundReactions) {
#        $count += (scalar(@{$foundReactions->{$seedRxn}}) - 1);
#        $self->createReactionModel($foundReactions->{$seedRxn}->[0], $labels, $seedRxn, $model->id());
#    }
#    warn "$count reactions removed from model upload!\n";
#    $model->processModel(); # update statistics, create directory, etc.
#    $model->message("Completed import of model.");
#    $retObject->{'msg'} = "Model import complete! View <a href='seedviewer.cgi?page=ModelView&model=".
#        $model->id()."'>your model</a> now!";
#    $retObject->{'success'} = "1";
#    $retObject->{'error'} = "0"; 
#    return $retObject;
} 

sub make_reaction_compound_map {
    my ($self, $foundCompounds, $labels) = @_;
    my $rxn_cpd_lookup_labels = $self->get_class_index('_rxn_cpd_map');
    my $reaction_compound_map = {};
    foreach my $cpd (keys %$foundCompounds) {
        my $found = 0;
        my $objs = $foundCompounds->{$cpd};
        my $value = undef;
        next unless(@$objs > 0); 
        foreach my $label (@$rxn_cpd_lookup_labels) {
            $value = $self->get_value_by_label($labels, $objs->[0], $label);
            next unless(defined($value));
        }
        if(defined($value)) {
            $reaction_compound_map->{$value} = $cpd;
        }
    }
    return $reaction_compound_map;
}

sub get_value_by_label {
    my ($self, $labelPaths, $obj, $label) = @_;
    my $value = undef;
    if(defined($labelPaths->{$label})) {
        foreach my $path (@{$labelPaths->{$label}}) {
            $value = $self->follow_path($path, $obj);
            next unless(defined($value));
            last;
        }
    } 
    return $value;
}


sub get_file {
    my ($self, $tag) = @_;
    my $uploadPath = "/vol/model-dev/MODEL_DEV_DB/tmp/";
    my $prefix = "model-rxnf-";
    if(-e $uploadPath . $prefix . $tag) {
        return $uploadPath . $prefix .$tag;
    } else {
        return undef;
    }
}
   
# makes an xml-path non-absolute and helpful for label_parsing
sub losen_path {
    my ($self, $label) = @_;
    $label =~ s/\/sbml\/model\/listOfSpecies\///;
    $label =~ s/\/sbml\/model\/listOfReactions\///;
    $label =~ s/\[\d+\]//g;
    return $label;
}

sub score_label {
    my ($self, $value, $oldScore) = @_;
    if(!defined($oldScore)) {
        $oldScore = {};
        my @keys = @{$self->get_index()};
        foreach my $key (@keys) {
            $oldScore->{$key} = 0;
        }
    }
    foreach my $key (keys %$oldScore) {
        if(scalar(@{$self->lookup($key, $value)}) > 0) {
            $oldScore->{$key}++;
        }
    }
    return $oldScore;
}

# Convert path -> { label => score } into
# label -> [paths] sorted by score
#
sub rot_labels {
    my ($self, $paths) = @_;
    foreach my $path (keys %$paths) {
        my $labelScores = [];
        foreach my $label (keys %{$paths->{$path}}) {
            push(@$labelScores, $label . "[" . $paths->{$path}->{$label} . "]");
        }
    }
    my $labels = {}; # label -> [paths] sorted by best path first
    my $tmp = {}; # label -> {path -> score}
    foreach my $path (keys %$paths) {
        my $label_scores = $paths->{$path};
        foreach my $label (keys %$label_scores) {
            if($label_scores->{$label} > 0) {
		#print $path,"\t",$label,"\t",$label_scores->{$label},"\n";
                $tmp->{$label} = {} unless(defined($tmp->{$label}));
                $tmp->{$label}->{$path} = $label_scores->{$label};
            }
        }
    }
    foreach my $label (keys %$tmp) {
        my $ps = $tmp->{$label};
        my @paths_by_score = sort { $ps->{$b} <=> $ps->{$a} } keys %$ps;
        $labels->{$label} = \@paths_by_score;
    }
    return $labels;
}
     
sub get_labels {
    my ($self, $reactionFile, $compoundFile) = @_;
    my $labels = [];
    if((!defined($compoundFile)) || $reactionFile eq $compoundFile) {
        my $parser = XML::LibXML->new();
        my $doc = $parser->parse_file($reactionFile);
        my $paths = {};
        # Need to generate index of compound ids used in reactions
        # Will use this path for translating reactionCompound => species[number] => cpd 
        my @cpdrefs = $doc->getElementsByTagName("speciesReference");
        my $cpdIdx = {};
        foreach my $cpdref (@cpdrefs) {
            my $cpdId = $cpdref->getAttribute("species");
            if(defined($cpdId)) {
                $cpdIdx->{$cpdId} = [1];
            }
        }
        $self->add_index('_rxn_cpd_map', $cpdIdx, ['_rxn_cpd_map']);
        # Now for each species, attempt to associate attributes with tags (name, reaction compound, kegg, seed)
        my @cpds = $doc->getElementsByTagName("species");
	$self->{_current_node_type}="species";
        foreach my $cpd (@cpds) {
            my @attrs = $cpd->attributes();
            foreach my $attr (@attrs) {
                my $path = $self->losen_path($attr->nodePath());
		#Only useful paths are id and name
		next if $path eq "species/\@compartment";
                if(not defined($paths->{$path})) {
                    $paths->{$path} = $self->score_label($attr->getValue());
                } else {
                    $paths->{$path} = $self->score_label($attr->getValue(), $paths->{$path});
                }
            }
        }
        my @rxns = $doc->getElementsByTagName("reaction");
	$self->{_current_node_type}="reaction";
        foreach my $rxn (@rxns) {
            my @attrs = $rxn->attributes();
            foreach my $attr (@attrs) {
                my $path = $self->losen_path($attr->nodePath());		
		#Only useful paths are id and name
                if(not defined($paths->{$path})) {
                    $paths->{$path} = $self->score_label($attr->getValue());
                } else {
                    $paths->{$path} = $self->score_label($attr->getValue(), $paths->{$path});
                }
            }
        }
	$self->{_current_node_type}="";
        return $self->rot_labels($paths);
    } else {    # tab delimited text
        my $paths = {};
        foreach my $file ($reactionFile, $compoundFile) {
            my $data = $self->read_flat_file($file);
            foreach my $row (@$data) {
                for(my $i=0; $i<@$row; $i++) {
                    if(not defined($paths->{$i})) {
                        $paths->{$i} = $self->score_label($row->[$i]);
                    } else {
                        $paths->{$i} = $self->score_label($row->[$i], $paths->{$i});
                    }
                }
            }
        }
        return $self->rot_labels($paths);
    }
}

sub read_flat_file {
    my ($self, $file) = @_;
    open(my $fh, "<", $file);
    my $data = [];
    while(<$fh>) {
        my @row = split(/\t/, $_);
        map { chomp $_ } @row; # remove trailing newlines
        push(@$data, \@row);
    }
    close($fh);
    return $data;
}

sub sbml_2_reaction {
    my ($self,$rxn)=@_;
    my $cmpt_search=join("",keys %{$self->{_compartment_index}});
    my ($eq,$cmpt) = $self->figmodel()->get_reaction_equation_sbml($rxn, $cmpt_search);
    return $eq;
}

sub bin_compounds {
    my ($self, $file, $types) = @_;
    my $foundCompounds = {};
    my $notFoundCompounds = [];
    my $parser = XML::LibXML->new();
    if(my $doc = $parser->parse_file($file)) { # sbml file
	#Seaver
	#07/01/11
	#Get compartments. Can remove compartments from
	#names and ids if found
	my @cmpts = $doc->getElementsByTagName("compartment");
	foreach my $cmpt(@cmpts){
	    $self->{_compartment_index}{$cmpt->getAttribute("id")}=1;
	}

        my @cpds = $doc->getElementsByTagName("species");
        my $idTypes = $self->get_class_index('_cpd_identity');
	$self->{_current_node_type}="species";
        foreach my $cpd (@cpds) {
            my $found = 0;
            foreach my $idType (@$idTypes) {
                next unless(defined($types->{$idType}));
                foreach my $path (@{$types->{$idType}}) {
		    next if $path eq "species/\@compartment";
		    my $value = $self->follow_path($path, $cpd);
                    next unless(defined($value));
                    my $ids = $self->lookup($idType, $value);
                    next unless(scalar(@$ids) > 0);
                    $foundCompounds->{$ids->[0]} = [] unless(defined($foundCompounds->{$ids->[0]}));
                    push(@{$foundCompounds->{$ids->[0]}}, $cpd);
                    $found = 1;
                    last;
                }
                last if($found);
            }
            if(not $found) {
                push(@$notFoundCompounds, $cpd);
            }
        }
	$self->{_current_node_type}="";
    } else {
        my $data = $self->read_flat_file($file);
        my $idTypes = $self->get_class_index('_cpd_identity');
        foreach my $row (@$data) {
            my $found = 0;
            foreach my $idType (@$idTypes) {
                next unless(defined($types->{$idType}));
                foreach my $path (@{$types->{$idType}}) {
                    my $value = $self->follow_path($path, $row);
                    next unless(defined($value));
                    my $ids = $self->lookup($idType, $value);
                    next unless(scalar(@$ids) > 0);
                    $foundCompounds->{$ids->[0]} = $row;
                    $found = 1;
                    last;
                }
                last if($found);
            }
            if(not $found) {
                push(@$notFoundCompounds, $row);
            }
        }
    }
    return ($foundCompounds, $notFoundCompounds);
}

sub bin_reactions {
    my ($self, $file, $types) = @_;
    my $foundReactions = {};
    my $notFoundReactions = [];
    my $stoichCount = 0;
    my $parser = XML::LibXML->new();
    if(my $doc = $parser->parse_file($file)) { # sbml file
        my @rxns = $doc->getElementsByTagName("reaction");
	$self->{_current_node_type}="reaction";
        my $loopCount = 0;
        foreach my $rxn (@rxns) {
            $loopCount++;
            my $eq = $self->sbml_2_reaction($rxn);
            my $found_ids = $self->lookup('rxn_equation', join(' ', @$eq));
            if(@$found_ids == 0) { # try to match on KEGG id, Seed id
                my $idTypes = $self->get_class_index('_rxn_other');
                foreach my $idType (@$idTypes) {
                    next unless(defined($types->{$idType}));
                    foreach my $path (@{$types->{$idType}}) {
                        my $value = $self->follow_path($path, $rxn);
                        next unless(defined($value));
                        $found_ids = $self->lookup($idType, $value);
                        last if(scalar(@$found_ids) > 0);
                    }
                    last if(@$found_ids > 0); 
                }
            }else{
		$stoichCount++;
	    }
            if(@$found_ids > 0) {
                $foundReactions->{$found_ids->[0]} = [] unless(defined($foundReactions->{$found_ids->[0]}));
                push(@{$foundReactions->{$found_ids->[0]}}, $rxn);   
            } else {
                push(@$notFoundReactions, $rxn);
            }
        }
	$self->{_current_node_type}="";
    } else {
        my $data = $self->read_flat_file($file);
        my $idTypes = $self->get_class_index('_rxn_eqs');
        my $nonEqTypes = $self->get_class_index('_rxn_other');
        push(@$idTypes, @$nonEqTypes); # First try on equation then on others
        foreach my $row (@$data) {
            my $found = 0;
            foreach my $idType (@$idTypes) {
                next unless(defined($types->{$idType}));
                foreach my $path (@{$types->{$idType}}) {
                    my $value = $self->follow_path($path, $row);
                    next unless(defined($value));
                    my $ids = $self->lookup($idType, $value);
                    next unless(scalar(@$ids) > 0);
                    $foundReactions->{$ids->[0]} = [] unless(defined($foundReactions->{$ids->[0]}));
                    push(@{$foundReactions->{$ids->[0]}},$row);
                    $found = 1;
                    last;
                }
                last if($found);
            }
            if(not $found) {
                push(@$notFoundReactions, $row);
            }
        }
    }
    return ($foundReactions, $notFoundReactions, $stoichCount);
}

sub follow_path {
    my ($self, $path, $obj) = @_;   
    unless(defined($path) && defined($obj)) {
        return undef;
    }
    if($path =~ /^\d+$/ && ref($obj) eq 'ARRAY') {
        return $obj->[$path];
    } elsif($path =~ /\@(.*)$/ && ref($obj) ne 'ARRAY') {
        my $attrName = $1;
        if(defined(my $attr = $obj->getAttribute($attrName))) { 
            return $attr;
        } else {
            return undef;
        }
    } else {
        return undef;
    }
}

sub eq_to_stuff {
    my ($self, $eq) = @_;
    my $equation = [];
    my $definition = [];
    foreach my $part (@$eq) {
        if($part =~ /\+/) {
            push(@$equation, $part);
            push(@$definition, $part);
        } elsif($part =~ /\(\d+\)/) {
            push(@$equation, $part);
            push(@$definition, $part);
        } elsif($part =~ /=>/) {
            push(@$equation, $part);
            push(@$definition, $part);
        } elsif($part =~ /<=>/) {
            push(@$equation, $part);
            push(@$definition, $part);
        } else {
            my $values = $self->lookup('rxn_cpd_equation', $part);
            if(@$values > 0) {
                push(@$equation, $values->[0]);
                $part = $values->[0];
            } else {
                push(@$equation, $part);
            }
            $values = $self->lookup('cpd_id_to_name', $part);
            if(@$values > 0) {
                push(@$definition, $values->[0]);
            } else {
                push(@$definition, $part);
            }
                 
        } 
    }
    $equation = join(' ', @$equation);
    $definition = join(' ', @$definition);
    warn $equation; 
    my ($dir, $code, $revCode, $eq2, $compartment, $error) =
        $self->figmodel()->ConvertEquationToCode($equation);
    return ($code, $eq2, $definition, $dir, $compartment );
}

sub model_info_setter {
    my ($self, $modelId, $info) = @_;
    my $modelHash = { 'name' => '', "owner" => "",
                      "public" => 0, "genome" => "unknown",
                      "source" => "unknown", "modificationDate" => time(),
                      "builtDate" => -1, "autocompleteDate" => -1,
                      "status" => -2, "version" => -1,
                      "autocompleteVersion" => 0,
                      "message" => "None",
                      "cellwalltype" => "unknown",
                      "associatedGenes" => -1,
                      "associatedSubsystemGenes" => -1,
                      "reactions" => -1,
                      "compounds" => -1,
                      "transporters" => -1,
                      "autoCompleteReactions" => -1,
                      "biologReactions" => -1,
                      "gapFillReactions" => -1,
                      "spontaneousReactions" => -1,
                      "autoCompleteTime" => -1,
                      "autocompletionDualityGap" => -1,
                      "autocompletionObjective" => -1,
                      "biomassReaction" => "NONE",
                      "growth" => 0,
                      "noGrowthCompounds" => "NONE",
                   };
    unless(defined($modelId)) {
        return $modelHash;
    }
    my $model = $self->figmodel()->database()->get_object('model', { 'id' => $modelId }); 
    if(defined($model) && defined($info)) {
        foreach my $key (keys %$info) {
            if(defined($modelHash->{$key})) {
                $model->$key($info->{$key});
            }
        }
        return $model;
    } elsif(defined($info) && ref($info) eq 'HASH') {
        return $self->figmodel()->database()->create_object('model', $info);
    } else {
        return $modelHash;
    }
}

1;
