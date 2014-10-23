package DB::Introspector::Oracle::Introspector;

use strict;

use base qw( DB::Introspector::CommonRDB::Introspector );


use constant SINGLE_TABLE_QUERY => 
q( SELECT LOWER(table_name) AS TABLE_NAME, LOWER(user) AS owner_name 
   FROM user_tables WHERE LOWER(table_name)=? );

use constant ALL_TABLES_QUERY => 
q( SELECT LOWER(table_name) AS table_name, LOWER(USER) AS owner_name 
   FROM user_tables );


sub _cached_table {
    my $self = shift;
    my $table_name = shift;
    return $self->SUPER::_cached_table(lc($table_name));
}

sub get_single_table_lookup_statement {
    my $self = shift;
    my $table_name = lc(shift);

    my $sth = $self->dbh->prepare_cached(SINGLE_TABLE_QUERY);
    $sth->execute($table_name);
    return $sth;
}

sub get_all_tables_lookup_statement {
    my $self = shift;
    my $sth = $self->dbh->prepare_cached(ALL_TABLES_QUERY);
    $sth->execute();
    return $sth;
}

sub get_table_class {
    return q(DB::Introspector::Oracle::Table);
}


package DB::Introspector::Oracle::Table;

use strict;

use base qw( DB::Introspector::CommonRDB::Table );

use constant COLUMN_LOOKUP_QUERY =>
q(SELECT LOWER(column_name) AS NAME, data_type AS TYPE, 
        DECODE(data_precision, NULL, data_length, data_precision) AS LENGTH 
    FROM user_tab_columns
    WHERE LOWER(table_name)=?);

# TODO add support for cross schema references
use constant FOREIGN_KEYS_LOOKUP_QUERY =>
q(SELECT constraint_name AS name FROM user_constraints 
  WHERE constraint_type='R' 
    AND LOWER(table_name)=?
    AND owner=r_owner);

use constant INDEXES_LOOKUP_QUERY =>
q(SELECT index_name AS name, uniqueness 
  FROM user_indexes
  WHERE LOWER(table_name)=?);

use constant DEPENDENCIES_LOOKUP_QUERY =>
q(SELECT dep.constraint_name AS name, dep.table_name AS child_table_name
  FROM  user_constraints dep, 
        user_constraints ent
  WHERE dep.constraint_type = 'R'
    AND dep.r_constraint_name = ent.constraint_name
    AND LOWER(ent.table_name) = ?);

use constant PRIMARY_KEY_LOOKUP_QUERY =>
q(SELECT LOWER(column_name) FROM user_cons_columns WHERE constraint_name IN (
    SELECT constraint_name FROM user_constraints 
        WHERE LOWER(table_name)=? 
          AND constraint_type='P'
 ) ORDER BY position); 

use DB::Introspector::Base::BooleanColumn;
use DB::Introspector::Base::SpecialColumn;
use DB::Introspector::Base::IntegerColumn;
use DB::Introspector::Base::CharColumn;
use DB::Introspector::Base::CLOBColumn;
use DB::Introspector::Base::StringColumn;
use DB::Introspector::Base::DateTimeColumn;

use constant COLUMN_CLASS_MAPPING => {
    'NUMBER' => 'DB::Introspector::Base::IntegerColumn',
    'LONG' => 'DB::Introspector::Base::IntegerColumn',
    'CHAR' => 'DB::Introspector::Base::CharColumn',
    'VARCHAR' => 'DB::Introspector::Base::StringColumn',
    'VARCHAR2' => 'DB::Introspector::Base::StringColumn',
    'DATE' => 'DB::Introspector::Base::DateTimeColumn',
    'TIMESTAMP(6)' => 'DB::Introspector::Base::DateTimeColumn',
    'CLOB' => 'DB::Introspector::Base::CLOBColumn',
    'ROWID' => 'DB::Introspector::Base::SpecialColumn',
    'UROWID' => 'DB::Introspector::Base::SpecialColumn',
};

sub get_primary_key_column_ids {
    my $self = shift;

    unless( $self->{_primary_key_column_ids} ) {
        my $sth =
          $self->_introspector->dbh->prepare_cached(PRIMARY_KEY_LOOKUP_QUERY);
        $sth->execute($self->name);
        my @columns = $self->columns; 
        my @ids;
        while( my ($column_name) = $sth->fetchrow_array ) {
            COLUMN_WALK: foreach my $i (0..$#columns) {
                if( $columns[$i]->name eq $column_name ) {
                    push(@ids, $i);
                    last COLUMN_WALK;
                }
            }
        }
        $sth->finish();
        $self->{_primary_key_column_ids} = \@ids;
    }
    return @{$self->{_primary_key_column_ids}};
}

sub get_column_lookup_statement {
    my $self = shift;

    my $sth = $self->_introspector->dbh->prepare_cached(COLUMN_LOOKUP_QUERY);
    $sth->execute(lc($self->name));

    return $sth;
}

sub get_foreign_keys_lookup_statement {
    my $self = shift;

    my $sth = $self->_introspector->dbh->prepare_cached(
        FOREIGN_KEYS_LOOKUP_QUERY);

    $sth->execute(lc($self->name));
    return $sth;
}

sub get_indexes_lookup_statement {
    my $self = shift;

    my $sth = $self->_introspector->dbh->prepare_cached(INDEXES_LOOKUP_QUERY);

    $sth->execute(lc($self->name));
    return $sth;
}

sub get_dependencies_lookup_statement {
    my $self = shift;

    my $sth = $self->_introspector->dbh->prepare_cached(
        DEPENDENCIES_LOOKUP_QUERY);

    $sth->execute(lc($self->name));
    return $sth;
}

sub get_column_instance {
    my $self = shift;
    my $name = shift;
    my $type_name = uc(shift);
    my $extra_data = shift;

    my $class = COLUMN_CLASS_MAPPING()->{$type_name}
                            || die("class not found for type:$type_name");

    if($class->isa('DB::Introspector::Base::IntegerColumn')) {
        # if we are dealing with an Integer then assume that our min and max
        # length is dependent on the number of acceptable characters in the
        # number
        my $max = '9' x $extra_data->{LENGTH};
        if( defined $max ) {
            return $class->new($name, -$max, $max);
        } else {
            return $class->new($name);
        }
    } elsif ($class->isa('DB::Introspector::Base::StringColumn')) {
        return $class->new($name, 0, $extra_data->{LENGTH});
    } else {
        return $class->new($name);
    }
}

sub get_foreign_key_class {
    return q(DB::Introspector::Oracle::ForeignKey);
}

sub get_index_class {
    return q(DB::Introspector::Oracle::Index);
}

package DB::Introspector::Oracle::ForeignKey;

use strict;

use base qw( DB::Introspector::CommonRDB::ForeignKey );

use constant LOCAL_COLUMN_NAME_QUERY => 
q(SELECT LOWER(column_name) AS NAME FROM user_cons_columns 
  WHERE constraint_name=?  ORDER BY position);

use constant FOREIGN_COLUMN_NAME_QUERY =>
q( SELECT /*+first_rows*/ LOWER(column_name) AS name
    FROM    user_constraints u,
            user_cons_columns c
    WHERE c.constraint_name=u.r_constraint_name
      AND u.constraint_name=? ORDER BY position);

use constant FOREIGN_TABLE_NAME_QUERY => 
q(SELECT LOWER(R.TABLE_NAME) AS NAME 
    FROM USER_CONSTRAINTS R, USER_CONSTRAINTS U 
    WHERE U.R_CONSTRAINT_NAME=R.CONSTRAINT_NAME
      AND U.CONSTRAINT_NAME=? );

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    my $table = shift;
    my $dependency = shift;
    my %args = @_;
    $self->{'_name'} = $args{'NAME'};
    return $self;
}

sub name {
    my $self = shift;
    return $self->{_name};
}

sub get_local_column_name_lookup_statement {
    my $self = shift;
    my $sth = $self->local_table->_introspector->dbh->prepare_cached(
        LOCAL_COLUMN_NAME_QUERY);
    $sth->execute($self->name);
    return $sth;
}

sub get_foreign_column_name_lookup_statement {
    my $self = shift;
    my $sth = $self->local_table->_introspector->dbh->prepare_cached(
        FOREIGN_COLUMN_NAME_QUERY);
    $sth->execute($self->name);
    return $sth;
}

sub get_foreign_table_name_lookup_statement {
    my $self = shift;
    my $sth = $self->local_table->_introspector->dbh->prepare_cached(
        FOREIGN_TABLE_NAME_QUERY);
    $sth->execute($self->name);
    return $sth;
}

package DB::Introspector::Oracle::Index;

use strict;

use base qw( DB::Introspector::CommonRDB::Index );
use constant UNIQUE => 'UNIQUE';

use constant COLUMN_NAME_LOOKUP_QUERY => 
q(SELECT LOWER(column_name) AS name FROM user_ind_columns WHERE index_name=? 
  ORDER BY column_position ASC); 

sub new {
    my $class = shift;
    my $table = shift;
    my %row = @_;

    my $self = $class->SUPER::new($table, $row{UNIQUENESS} eq UNIQUE());
    $self->{_name} = $row{NAME};

    $self;
}

sub name {
    my $self = shift;
    return $self->{_name};
}

sub get_column_name_lookup_statement {
    my $self = shift;
    my $sth = $self->table->_introspector->dbh->prepare_cached(
        COLUMN_NAME_LOOKUP_QUERY);
    $sth->execute($self->name);
    return $sth;
}


1;
