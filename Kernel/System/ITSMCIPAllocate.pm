# --
# Kernel/System/ITSMCIPAllocate.pm - all criticality, impact and priority allocation functions
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMCIPAllocate;

use strict;
use warnings;

=head1 NAME

Kernel::System::ITSMCIPAllocate - criticality, impact and priority allocation lib

=head1 SYNOPSIS

All criticality, impact and priority allocation functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::Config;
    use Kernel::System::Encode;
    use Kernel::System::Log;
    use Kernel::System::ITSMCIPAllocate;
    use Kernel::System::DB;
    use Kernel::System::Main;

    my $ConfigObject = Kernel::Config->new();
    my $EncodeObject = Kernel::System::Encode->new(
        ConfigObject => $ConfigObject,
    );
    my $LogObject = Kernel::System::Log->new(
        ConfigObject => $ConfigObject,
        EncodeObject => $EncodeObject,
    );
    my $MainObject = Kernel::System::Main->new(
        ConfigObject => $ConfigObject,
        EncodeObject => $EncodeObject,
        LogObject    => $LogObject,
    );
    my $DBObject = Kernel::System::DB->new(
        ConfigObject => $ConfigObject,
        EncodeObject => $EncodeObject,
        LogObject    => $LogObject,
        MainObject   => $MainObject,
    );
    my $CIPAllocateObject = Kernel::System::ITSMCIPAllocate->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        DBObject     => $DBObject,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Object (qw(DBObject ConfigObject LogObject)) {
        $Self->{$Object} = $Param{$Object} || die "Got no $Object!";
    }

    return $Self;
}

=item AllocateList()

return a 2d hash reference of allocations

    my $ListRef = $CIPAllocateObject->AllocateList(
        UserID => 1,
    );

C<$ListRef> is something like

    $ListRet = {
        '3 normal' => {
            '1 very low' => 1,
            '3 normal'   => 2,
            '4 high'     => 3,
        },
        '5 very high' => {
            '2 low'    => 3,
            '3 normal' => 4,
            '4 high'   => 5,
        },
    };

meaning that the Criticality '3 normal' and the Impact '1 very low' suggest the PriorityID '1'.

=cut

sub AllocateList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need UserID!',
        );
        return;
    }

    # ask database
    $Self->{DBObject}->Prepare(
        SQL => 'SELECT criticality, impact, priority_id FROM cip_allocate',
    );

    # result list
    my %AllocateData;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $AllocateData{ $Row[1] }{ $Row[0] } = $Row[2];
    }

    return \%AllocateData;
}

=item AllocateUpdate()

update the allocation of criticality, impact and priority

    my $True = $CIPAllocateObject->AllocateUpdate(
        AllocateData => $DataRef,  # 2D hash reference
        UserID       => 1,
    );

=cut

sub AllocateUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(AllocateData UserID)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # check if allocate data is a hash reference
    if ( ref $Param{AllocateData} ne 'HASH' ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'AllocateData must be a 2D hash reference!',
        );
        return;
    }

    # check if allocate data is a 2D hash reference
    IMPACT:
    for my $Impact ( sort keys %{ $Param{AllocateData} } ) {

        next IMPACT if ref $Param{AllocateData}->{$Impact} eq 'HASH';

        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'AllocateData must be a 2D hash reference!',
        );
        return;
    }

    # delete old allocations
    $Self->{DBObject}->Do( SQL => 'DELETE FROM cip_allocate' );

    # insert new allocations
    for my $Impact ( sort keys %{ $Param{AllocateData} } ) {

        for my $Criticality ( sort keys %{ $Param{AllocateData}->{$Impact} } ) {

            # extract priority
            my $PriorityID = $Param{AllocateData}->{$Impact}->{$Criticality};

            # insert new allocation
            $Self->{DBObject}->Do(
                SQL => 'INSERT INTO cip_allocate '
                    . '(criticality, impact, priority_id, '
                    . 'create_time, create_by, change_time, change_by) VALUES '
                    . '(?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
                Bind => [
                    \$Criticality, \$Impact, \$PriorityID,
                    \$Param{UserID}, \$Param{UserID},
                ],
            );
        }
    }

    return 1;
}

=item PriorityAllocationGet()

return the priority id of a criticality and an impact

    my $PriorityID = $CIPAllocateObject->PriorityAllocationGet(
        Criticality => '1 very low',
        Impact      => '3 normal',
    );

=cut

sub PriorityAllocationGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Criticality Impact)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get priority id from db
    $Self->{DBObject}->Prepare(
        SQL => 'SELECT priority_id FROM cip_allocate '
            . 'WHERE criticality = ? AND impact = ?',
        Bind => [ \$Param{Criticality}, \$Param{Impact} ],
        Limit => 1,
    );

    # fetch result
    my $PriorityID;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $PriorityID = $Row[0];
    }

    return $PriorityID;
}

1;

=back

=head1 TERMS AND CONDITIONS

This Software is part of the OTRS project (http://otrs.org/).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
