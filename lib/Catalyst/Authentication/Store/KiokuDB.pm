package Catalyst::Authentication::Store::KiokuDB;

use strict;
use warnings;

our $VERSION = '0.01';

use Catalyst::Authentication::User::KiokuDB;
use Search::GIN::Extract::Class;
use Search::GIN::Extract::Attributes;
use Search::GIN::Extract::Multiplex;
use Search::GIN::Query::Attributes;
use KiokuDB;
use KiokuDB::Backend::BDB::GIN;

sub new {
    my ($class, $conf, $app, $realm) = @_;

    my %self;
    if ($conf->{kiokuObject}) {
        $self{kioku} = $conf->{kiokuObject};
    }
    elsif ($conf->{kiokuDir}) {
        $self{kioku} = KiokuDB->new(
                backend => KiokuDB::Backend::BDB::GIN->new(
                    manager => { home => $conf->{kiokuDir}, create  => 1 },
                    extract => Search::GIN::Extract::Multiplex->new({
                        extractors  => [
                            Search::GIN::Extract::Class->new,
                            Search::GIN::Extract::Attributes->new,
                        ]
                    })
                ),
        );
    }
    else {
        Catalyst::Exception->throw( 
            message => "KiokuDB requires at least 'kiokuObject' or 'kiokuDir' to be set."
        );
    }

    $self{kiokuScope} = $self{kioku}->new_scope();
    return bless \%self, $class;
}

sub from_session {
	my ($self, $c, $id) = @_;

	return $id if ref $id;
    return $self->find_user({ id => $id });
}

sub find_user {
    my ($self, $userinfo, $c) = @_;

    return $self->{kioku}->lookup($userinfo->{id}) if $userinfo->{id};
    my $q = Search::GIN::Query::Attributes->new({ attributes => $userinfo });
    my @res = $self->{kioku}->search($q)->all; # XXX can't we just get the first?
    return $res[0];
}

sub user_supports {
    my $self = shift;
    return Catalyst::Authentication::User::KiokuDB->supports(@_);
}

sub get_user {
    my ($self, $id) = @_;
    $self->find_user({id => $id});
}

1;

=pod

=head1 NAME

Catalyst::Authentication::Store::KiokuDB - KiokuDB store for auth

=head1 SYNOPSIS

    use Catalyst qw/
        Authentication
    /;

    __PACKAGE__->config->{'Plugin::Authentication'} = 
                    {  
                        default_realm => 'admin',
                        realms => {
                            admin => {
                                credential => {
                                    class           => 'Password',
                                    password_field  => 'password',
                                    password_type   => 'clear'
                                },
                                store => {
                                    class       => 'KiokuDB',
                                    kiokuDir    => '/path/to/some/dir',
                	            }
                	        }
                    	}
                    };

    
=head1 DESCRIPTION

This is a simple authentication store that uses KiokuDB as its backend storage.
It is recommended if you are already using KiokuDB and wish to centralise all
of your storage there.

=head1 CONFIGURATION

Only one of the following should be specified.

=over 4

=item kiokuDir

This is the path to the directory in which you tell KiokuDB to store its data.

=item kiokuObject

This is an already instantiated KiokuDB object which you wish to reuse to
store you data with. This object needs to support searching based on 
attributes.

=back

=head1 METHODS

This store implements no methods outside of those required by its base class.

=head1 AUTHOR

Robin Berjon, <robin@berjon.com>, L<http://robineko.com/>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
