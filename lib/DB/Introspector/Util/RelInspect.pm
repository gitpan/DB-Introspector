package DB::Introspector::Util::RelInspect;

use strict;
use DB::Introspector::ForeignKeyPath;


sub find_paths_between_tables {
    my $class = shift;
    my $root_table = shift;
    my $child_table = shift;
    my $path = shift ||  new DB::Introspector::ForeignKeyPath();
    my $path_list = shift || [];

    if( $root_table->name eq $child_table->name ) {
        push(@$path_list, $path);
        return;
    }

    foreach my $foreign_key ($child_table->foreign_keys) {
        my $internal_path = $path->clone();
        $internal_path->prepend_foreign_key($foreign_key);
        $class->find_paths_between_tables( $root_table,
                                           $foreign_key->foreign_table, 
                                           $internal_path, 
                                           $path_list );
    }

    return $path_list;
}


1;
