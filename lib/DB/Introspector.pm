package DB::Introspector;

use strict;

use DBI;
use Config::Properties;
use IO::File;

use constant DRIVER_PROPERTIES_FILE => 'driver.properties';

use vars qw( %REGISTRY %INC );

DB::Introspector->register_drivers();


sub find_table {
    my $self = shift;
    die("find_table method not defined in ". (ref($self) || $self)); 
}


sub find_all_tables {
    my $self = shift;
    die("find_all_tables method not defined in ". (ref($self) || $self)); 
}



sub register_drivers {
    my $class = shift;

    my $driver_filename = $INC{'DB/Introspector.pm'};
    $driver_filename =~ s@.pm$@/@g;
    $driver_filename .= DRIVER_PROPERTIES_FILE;

    my $properties_fh = new IO::File("<$driver_filename")
        || die("Can't open $driver_filename");

    my $properties = new Config::Properties();
    $properties->load($properties_fh);

    foreach my $name ($properties->propertyNames) {
        my $class_name = $properties->getProperty($name);
        eval("use $class_name;");
        if($@) {
            warn("Could not register $class_name because: \n $@");
        }
        $class->register_introspector_class( $name, $class_name );
    }
} 

sub get_instance {
    my $class = shift;
    my $dbh = shift;

    die("$class->new requires a dbh.") unless( UNIVERSAL::isa($dbh, 'DBI::db'));

    my $driver_name = $dbh->{Driver}->{Name};


    my $introspector_class = $class->_lookup_introspector_class($driver_name)
        || die("no introspector found for driver: $driver_name");

    return $introspector_class->new($dbh);
}

sub _lookup_introspector_class {
    my $class = shift;
    my $driver_name = lc(shift);

    $REGISTRY{$driver_name};
}

sub register_introspector_class {
    my $class = shift;
    my $driver_name = lc(shift);
    my $introspector_class = shift;

    $REGISTRY{$driver_name} = $introspector_class;
}

sub registered_drivers {
    return keys %REGISTRY;
}




sub new {
    my $class = shift;
    my $dbh = shift;

    unless( UNIVERSAL::isa($dbh, 'DBI::db') ) {
        die("$class->new requires a dbh.");
    }

    my $self = bless({
        _dbh => $dbh
    }, ref($class) || $class);

    $self;
}

sub dbh {
    my $self = shift;
    return $self->{_dbh};
}



1;
__END__

=head1 NAME

DB::Introspector

=head1 SYNOPSIS

 use DB::Introspector;
 
 my $introspector = DB::Introspector->get_instance($dbh);
 
 my $table = $introspector->find_table('foo');
 
 print $table->name;
 
 foreach my $foreign_key ($table->foreign_keys) {

     print $foreign_key->foreign_table->name;

     print join(",",$foreign_key->foreign_column_names);

 }
 
 my @tables = $introspector->find_tables;

=head1 DESCRIPTION

DB::Introspector looks into database metadata and derives detailed table level
and foreign key information in a way that conforms to a collection common
interfaces across all dbs. The DB::Introspector::Utils::* classes take
advantage of these common interfaces in order to carry out relationship
traversal algorithms (like finding the column level and table level mappings
between two indirectly related tables). 

=head1 ABSTRACT METHODS

=over 4



=item $introspector->find_table($table_name)

=over 4

Params:

=over 4

$table_name - the name of the table that you wish to find

=back

Returns: DB::Introspector::Base::Table

=back




=item $introspector->find_all_tables

=over 4

Returns: An array (@) of DB::Introspector::Base::Table instances for each table that exists in the database.

=back

=back


=head1 METHODS

=over 4        

=item DB::Introspector->get_instance($dbh)

=over 4

Params:

=over 4

$dbh - An instance of a DBI database handle.

=back

Returns: DB::Introspector instance

=back




=item $introspector->dbh

=over 4

Returns: A DBI database handle instance (DBI::db).

=back


=back


=head1 SEE ALSO

=over 4

L<DB::Introspector::Base::Table>

L<DB::Introspector::Base::ForeignKey>

L<DB::Introspector::Utils::RelInspect>

L<DB::Introspector::Base::BooleanColumn>

L<DB::Introspector::Base::CharColumn>

L<DB::Introspector::Base::Column>

L<DB::Introspector::Base::DateTimeColumn>

L<DB::Introspector::Base::IntegerColumn>

L<DB::Introspector::Base::StringColumn>

L<DBI>

=back


=head1 AUTHOR

Masahji C. Stewart

=head1 COPYRIGHT

The DB::Introspector module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
