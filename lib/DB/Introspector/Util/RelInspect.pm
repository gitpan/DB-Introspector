package DB::Introspector::Util::RelInspect;

use strict;
use DB::Introspector::ForeignKeyPath;
use DB::Introspector::MappedPath;

use vars qw( $SINGLETON );

sub _instance {
    my $class = shift;
    $SINGLETON ||= bless(\$class, $class);
    return $SINGLETON;
}

sub find_mapped_paths_between_tables {
    my $class = shift;
    my $root_table = shift;
    my $child_table = shift;
    my $path = shift ||  new DB::Introspector::MappedPath();
    my $path_list = shift || [];

    if( $root_table->name eq $child_table->name ) {
        unshift(@$path_list, $path);
        return [];
    }

    foreach my $foreign_key ($child_table->foreign_keys) {
        next if($foreign_key->local_table->name 
             eq $foreign_key->foreign_table->name);
        my $internal_path = $path->clone();
        $internal_path->prepend_foreign_key($foreign_key);
        $class->find_mapped_paths_between_tables( $root_table,
                                           $foreign_key->foreign_table, 
                                           $internal_path, 
                                           $path_list );
    }

    return $path_list;
}

sub find_paths_between_two_tables {
    my $class = shift;
    my $table_a = shift;
    my $table_b = shift;
    my $visited = shift || {};
    my $path = shift || new DB::Introspector::ForeignKeyPath;
    my $path_list = shift || [];

    if( $table_a->name eq $table_b->name ) {
        unshift(@$path_list, $path); 
        return;
 
   }

    return if( $visited->{$table_b->name} );
    local $visited->{$table_b->name} = 1;


    foreach my $foreign_key (   $table_b->foreign_keys ) {
        my $internal_path = $path->clone();
        $internal_path->prepend_foreign_key($foreign_key);
        $class->find_paths_between_two_tables( $table_a,
                                           $foreign_key->foreign_table,
                                           $visited, 
                                           $internal_path,
                                           $path_list ); 
    }


    foreach my $foreign_key (   $table_b->dependencies ) {
        my $internal_path = $path->clone();
        $internal_path->prepend_foreign_key($foreign_key);
        $class->find_paths_between_two_tables( $table_a,
                                           $foreign_key->local_table,
                                           $visited, 
                                           $internal_path,
                                           $path_list ); 
    }

    return $path_list;
}


1;
__END__

=head1 NAME

DB::Introspector::Util::RelInspect

=head1 SYNOPSIS

 use DB::Introspector::Util::RelInspect;

 my @paths = DB::Introspector::Util::RelInspect
             ->find_mapped_paths_between_tables( $parent_table, $child_table );
     
=head1 DESCRIPTION

DB::Introspector::Util::RelInspect is a utility class that contains methods
that deal with relationship traversal.

=head1 METHODS

=over 4



=item find_mapped_paths_between_tables($parent_table, $child_table)

=over 4

Params:

=over 4

$parent_table - the first element of each path

$child_table - the last element of each path 

=back

Returns: All paths between $parent_table and $child_table where $child_table
depends on $parent_table, even indirectly.

=back



=back


=head1 SEE ALSO

=over 4

L<DB::Introspector>


=back


=head1 AUTHOR

Masahji C. Stewart

=head1 COPYRIGHT

The DB::Introspector::Util::RelInspect module is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=cut
