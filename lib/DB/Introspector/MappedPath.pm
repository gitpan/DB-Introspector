package DB::Introspector::MappedPath;

use strict;
use base qw( DB::Introspector::ForeignKeyPath );



sub head_for_tail_column {
    my $self = shift;
    my $tail_column_name = shift;

    my @head_columns = $self->head_columns;
    my @tail_columns = $self->tail_columns;

    foreach my $index (0..$#tail_columns) {
        return $head_columns[$index]
            if( $tail_columns[$index] eq $tail_column_name );
    }
    return undef;
}

sub tail_for_head_column {
    my $self = shift;
    my $head_column_name = shift;

    my @tail_columns = $self->tail_columns;
    my @head_columns = $self->head_columns;

    foreach my $index (0..$#head_columns) {
        return $tail_columns[$index]
            if( $head_columns[$index] eq $head_column_name );
    }
    return undef;
}

1;
