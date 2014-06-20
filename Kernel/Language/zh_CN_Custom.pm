# --
# Kernel/Language/xx_Custom.pm - provides xx custom language translation
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Language::zh_CN_Custom;

use strict;
use warnings;

sub Data {
    my $Self = shift;

    # $$START$$

      $Self->{Translation} = {
            %{$Self->{Translation}},
            'Dashboard' => '信息中心',
            #'Zip' => '工号',
            'CustomerID' => '工号',
            'Tip: Your User Name' => '用户名是您开机登陆 windows 系统的用户名, 密码是您开机登陆 windows 系统的密码!',
            'Powered by' => ' ',
            'Tip: Type' => '地点',
            'Tip: Subject' => '标题',
            'Tip: Text' => '描述',
        };

    # $$STOP$$
}

1;
