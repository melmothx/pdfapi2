#=======================================================================
#    ____  ____  _____              _    ____ ___   ____
#   |  _ \|  _ \|  ___|  _   _     / \  |  _ \_ _| |___ \
#   | |_) | | | | |_    (_) (_)   / _ \ | |_) | |    __) |
#   |  __/| |_| |  _|    _   _   / ___ \|  __/| |   / __/
#   |_|   |____/|_|     (_) (_) /_/   \_\_|  |___| |_____|
#
#   A Perl Module Chain to faciliate the Creation and Modification
#   of High-Quality "Portable Document Format (PDF)" Files.
#
#   Copyright 1999-2005 Alfred Reibenschuh <areibens@cpan.org>.
#
#=======================================================================
#
#   This library is free software; you can redistribute it and/or
#   modify it under the terms of the GNU Lesser General Public
#   License as published by the Free Software Foundation; either
#   version 2 of the License, or (at your option) any later version.
#
#   This library is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#   Lesser General Public License for more details.
#
#   You should have received a copy of the GNU Lesser General Public
#   License along with this library; if not, write to the
#   Free Software Foundation, Inc., 59 Temple Place - Suite 330,
#   Boston, MA 02111-1307, USA.
#
#   $Id$
#
#=======================================================================
package PDF::API2::Resource::Font;

BEGIN {

    use utf8;
    use Encode qw(:all);

    use PDF::API2::Util;
    use PDF::API2::Basic::PDF::Utils;
    use PDF::API2::Resource::BaseFont;

    use POSIX;

    use vars qw(@ISA $VERSION);

    @ISA = qw( PDF::API2::Resource::BaseFont );

    ( $VERSION ) = '2.002';

}
no warnings qw[ deprecated recursion uninitialized ];

=item $font->encodeByData $encoding

Encodes the font in the specified byte-encoding.

=cut

sub encodeByData {
    my ($self,$encoding)=@_;
    my $data=$self->data;

    my ($firstChar,$lastChar);

    if($self->issymbol || $encoding eq 'asis') {
        $encoding=undef;
    }

    if(defined $encoding && $encoding=~m|^uni(\d+)$|o) 
    {
        my $blk=$1;
        $data->{e2u}=[ map { $blk*256+$_ } (0..255) ];
        $data->{e2n}=[ map { nameByUni($_) || '.notdef' } @{$data->{e2u}} ];
        $data->{firstchar} = 0;
    }
    elsif(defined $encoding) 
    {
        $data->{e2u}=[ unpack('U*',decode($encoding,pack('C*',(0..255)))) ];
        $data->{e2n}=[ map { nameByUni($_) || '.notdef' } @{$data->{e2u}} ];
    } 
    elsif(defined $data->{uni}) 
    {
        $data->{e2u}=[ @{$data->{uni}} ];
        $data->{e2n}=[ map { $_ || '.notdef' } @{$data->{char}} ];
    } 
    else 
    {
        $data->{e2u}=[ map { uniByName($_) } @{$data->{char}} ];
        $data->{e2n}=[ map { $_ || '.notdef' } @{$data->{char}} ];
    }

    $data->{u2c}={};
    $data->{u2e}={};
    $data->{u2n}={};
    $data->{n2c}={};
    $data->{n2e}={};
    $data->{n2u}={};

    foreach my $n (0..255) {
        my $xchar=undef;
        my $xuni=undef;
        if(defined $data->{char}->[$n]) {
            $xchar=$data->{char}->[$n];
        } else {
            $xchar='.notdef';
        }
        $data->{n2c}->{$xchar}=$n unless(defined $data->{n2c}->{$xchar});

        if(defined $data->{e2n}->[$n]) {
            $xchar=$data->{e2n}->[$n];
        } else {
            $xchar='.notdef';
        }
        $data->{n2e}->{$xchar}=$n unless(defined $data->{n2e}->{$xchar});

        $data->{n2u}->{$xchar}=$data->{e2u}->[$n] unless(defined $data->{n2u}->{$xchar});

        if(defined $data->{char}->[$n]) {
            $xchar=$data->{char}->[$n];
        } else {
            $xchar='.notdef';
        }
        if(defined $data->{uni}->[$n]) {
            $xuni=$data->{uni}->[$n];
        } else {
            $xuni=0;
        }
        $data->{n2u}->{$xchar}=$xuni unless(defined $data->{n2u}->{$xchar});

        $data->{u2c}->{$xuni}||=$n unless(defined $data->{u2c}->{$xuni});
        
        if(defined $data->{e2u}->[$n]) {
            $xuni=$data->{e2u}->[$n];
        } else {
            $xuni=0;
        }
        $data->{u2e}->{$xuni}||=$n unless(defined $data->{u2e}->{$xuni});

        if(defined $data->{e2n}->[$n]) {
            $xchar=$data->{e2n}->[$n];
        } else {
            $xchar='.notdef';
        }
        $data->{u2n}->{$xuni}=$xchar unless(defined $data->{u2n}->{$xuni});

        if(defined $data->{char}->[$n]) {
            $xchar=$data->{char}->[$n];
        } else {
            $xchar='.notdef';
        }
        if(defined $data->{uni}->[$n]) {
            $xuni=$data->{uni}->[$n];
        } else {
            $xuni=0;
        }
        $data->{u2n}->{$xuni}=$xchar unless(defined $data->{u2n}->{$xuni});
    }

    my $en = PDFDict();
    $self->{Encoding}=$en;

    $en->{Type}=PDFName('Encoding');
    $en->{BaseEncoding}=PDFName('WinAnsiEncoding');

    $en->{Differences}=PDFArray(PDFNum(0));
    foreach my $n (0..255) {
        $en->{Differences}->add_elements( PDFName($self->glyphByEnc($n) || '.notdef') );
    }

    $self->{'FirstChar'} = PDFNum($data->{firstchar});
    $self->{'LastChar'} = PDFNum($data->{lastchar});

    $self->{Widths}=PDFArray();
    foreach my $n ($data->{firstchar}..$data->{lastchar}) {
        $self->{Widths}->add_elements( PDFNum($self->wxByEnc($n)) );
    }

#use Data::Dumper;
#    print Dumper($data);

    return($self);
}

sub automap {
    my ($self)=@_;
	my $data=$self->data;
	
    my %gl=map { $_=>defineName($_) } keys %{$data->{wx}};

    foreach my $n (0..255) {
        delete $gl{$data->{e2n}->[$n]};
    }
    
    if(defined $data->{comps} && !$self->{-nocomps})
    {
        foreach my $n (keys %{$data->{comps}}) 
        {
            delete $gl{$n};
        }
    }

    my @nm=sort { $gl{$a} <=> $gl{$b} } keys %gl;

    my @fnts=();
    my $count=0;
    while(@glyphs=splice(@nm,0,223)) 
    {
        my $obj=$self->SUPER::new($self->{' apipdf'},$self->name.'am'.$count);
        $obj->{' data'}={ %{$data} };
        $obj->data->{firstchar}=32;
        $obj->data->{lastchar}=32+scalar(@glyphs);
        push @fnts,$obj;
        foreach my $key (qw( Subtype BaseFont FontDescriptor )) 
        {
            $obj->{$key}=$self->{$key} if(defined $self->{$key});
        }
        $obj->data->{char}=[];
        $obj->data->{uni}=[];
        foreach my $n (0..31) 
        {
            $obj->data->{char}->[$n]='.notdef';
            $obj->data->{uni}->[$n]=0;
        }
        $obj->data->{char}->[32]='space';
        $obj->data->{uni}->[32]=32;
        foreach my $n (33..$obj->data->{lastchar}) 
        {
            $obj->data->{char}->[$n]=$glyphs[$n-33];
            $obj->data->{uni}->[$n]=$gl{$glyphs[$n-33]};
        }
        foreach my $n (($obj->data->{lastchar}+1)..255) 
        {
            $obj->data->{char}->[$n]='.notdef';
            $obj->data->{uni}->[$n]=0;
        }
        $obj->encodeByData(undef);

        $count++;
    }

    return(@fnts);
}

sub remap {
    my ($self,$enc)=@_;

    my $obj=$self->SUPER::new($self->{' apipdf'},$self->name.'rm'.pdfkey());
    $obj->{' data'}={ %{$self->data} };
    foreach my $key (qw( Subtype BaseFont FontDescriptor )) {
        $obj->{$key}=$self->{$key} if(defined $self->{$key});
    }

    $obj->encodeByData($enc);

    return($obj);
}

1;

__END__

=head1 AUTHOR

alfred reibenschuh

=cut
