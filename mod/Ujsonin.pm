# Copyright (c) 2024 Dry Ark LLC
package Ujsonin;

my $handlers = {};

sub handle_true {
    my ( $data, $pos ) = @_;
    return { node => 1 }; #{ _type => 6 } };
}

sub handle_false {
    my ( $data, $pos ) = @_;
    return { node => 0 }; #{ _type => 7 } };
}

sub handle_null {
    my ( $data, $pos ) = @_;
    return { node => 0 }; #{ _type => 8 } };
}

sub init {
    $handlers->{"true"} = [ \&handle_true, 0 ];
    $handlers->{"false"} = [ \&handle_false, 0 ];
    $handlers->{"null"} = [ \&handle_null, 0 ];
}

sub parse {
    my ( $data, $beginState ) = @_;
    my $pos = 0;
    my $endstate = 0;
    my $neg = 0;
    my ( $keyLen,$typeStart,$keyStart,$strStart,$let,@stack );
    my $root = { _type => 1 };
    my $cur = $root;
    my $len = length( $data );
Begin:
    goto Done if( $pos >= $len );
    $let = substr( $data, $pos++, 1 );
    #print "Let: $let\n";
    if( $let eq '{' ) { goto Hash; }
    if( $let eq '[' ) {
        #print "Starting with array\n";
        $root = $cur = { _parent => undef, _type => 3, arr => [] };
        goto AfterColon;
    }
    goto Begin;
Hash:
    goto Done if( $pos >= $len );
    $let = substr( $data, $pos++, 1 );
    if( $let eq '"' ) { goto QQKeyName1; }
    if( $let eq '\'' ) { goto QKeyName1; }
    if( ord($let) >= ord('a') && ord($let) <= ord('z') ) { $pos--; goto KeyName1; }
    if( $let eq '}' && $cur->{_parent} ) {
        $cur = $cur->{_parent};
        if( $cur->{_type} == 3 ) { goto AfterColon; }
        goto Hash;
    }
    if( $let eq '/' && $pos < ($len-1) ) {
        if( substr( $data, $pos, 1 ) eq '/' ) { $pos++; goto HashComment; }
        if( substr( $data, $pos, 1 ) eq '*' ) { $pos++; goto HashComment2; }
    }
    goto Hash;
HashComment:
    goto Done if( $pos >= $len );
    $let = substr( $data, $pos++, 1 );
    if( $let eq "\x0d" || $let eq "\x0a" ) { goto Hash; }
    goto HashComment;
HashComment2:
    goto Done if( $pos >= $len );
    $let = substr( $data, $pos++, 1 );
    if( $let eq '*' && $pos < ($len-1) && substr( $data, $pos, 1 ) eq '/' ) { $pos++; goto Hash; }
    goto HashComment2;
QQKeyName1:
    goto Done if( $pos >= $len );
    $let = substr( $data, $pos, 1 );
    $keyStart = $pos++;
    if( $let eq '\\' ) { $pos++; }
QQKeyNameX: 
    goto Done if( $pos >= $len );
    $let = substr( $data, $pos++, 1 );
    if( $let eq '\\' ) { $pos++; goto QQKeyNameX; }
    if( $let eq '"' ) {
        $keyLen = ( $pos-1 ) - $keyStart;
        goto Colon;
    }
    goto QQKeyNameX;
QKeyName1:
    goto Done if( $pos >= $len );
    $let = substr( $data, $pos, 1 );
    $keyStart = substr( $data, $pos++, 1 );
    if( $let eq '\\' ) { $pos++; }
QKeyNameX: $let = substr( $data, $pos++, 1 );
    if( $let eq '\\' ) { $pos++; goto QKeyNameX; }
    if( $let eq '\'' ) {
        $keyLen = ( $pos-1 ) - $keyStart;
        goto Colon;
    }
    goto QKeyNameX;
KeyName1:
    goto Done if( $pos >= $len );
    $let = substr( $data, $pos, 1 );
    $keyStart = $pos++;
KeyNameX: 
    goto Done if( $pos >= $len );
    $let = substr( $data, $pos++, 1 );
    if( $let eq ':' ) {
        $keyLen = ($pos-1) - $keyStart;
        goto AfterColon;
    }
    if( $let eq ' ' || $let eq '\t' ) {
        $keyLen = ($pos-1) - $keyStart;
        goto Colon;
    }
    goto KeyNameX;
Colon:
    goto Done if( $pos >= $len );
    $let = substr( $data, $pos++, 1 );
    if( $let eq ':' ) { goto AfterColon; }
    goto Colon;
AfterColon: 
    goto Done if( $pos >= $len );
    $let = substr( $data, $pos++, 1 );
    if( $let eq '"' ) { goto String1; }
    if( $let eq '{' ) {
        my $newHash = { _type => 1, _parent => $cur };
        #$newHash->{_parent} = $cur;
        if( $cur->{_type} == 1 ) { $cur->{ substr( $data, $keyStart, $keyLen ) } = $newHash; }
        if( $cur->{_type} == 3 ) { push( @{$cur->{arr}}, $newHash ); }
        $cur = $newHash;
        goto Hash;
    }
    if( ord($let) >= ord('a') && ord($let) <= ord('z') ) {
        $typeStart = $pos - 1;
        goto TypeX;
    }
    if( $let eq '/' && $pos < ($len-1) ) {
        if( substr( $data, $pos, 1 ) eq '/' ) { $pos++; goto AC_Comment; }
        if( substr( $data, $pos, 1 ) eq '*' ) { $pos++; goto AC_Comment2; }
    }
    # if( $let == 't' || $let == 'f' ) ... for true/false
    if( ord($let) >= ord('0') && ord($let) <= ord('9') ) { $neg=0; goto Number1; }
    if( $let eq '-' ) { $neg=1; $pos++; goto Number1; }
    if( $let eq '[' ) {
        push( @stack, $cur );
        my $arr = [];
        my $newArr = { _parent => $cur, _type => 3, arr => $arr };
        if( $cur->{_type} == 1 ) { $cur->{ substr( $data, $keyStart, $keyLen ) } = $arr; }
        if( $cur->{_type} == 3 ) { push( @{$cur->{arr}}, $arr ); }
        $cur = $newArr;
        goto AfterColon;
    }
    if( $let eq ']' ) {
        $cur = pop( @stack ); #$cur->{_parent};
        if( !$cur ) { goto Done; }
        if( $cur->{_type} == 3 ) { goto AfterColon; }
        if( $cur->{_type} == 1 ) { goto Hash; }
        # should never reach here
    }
    goto AfterColon;
TypeX: 
    goto Done if( $pos >= $len );
    $let = substr( $data, $pos++, 1 );
    if( ( ord($let) >= ord('0') && ord($let) <= ord('9') ) || ( ord($let) >= ord('a') && ord($let) <= ord('z') ) ) { goto TypeX; }
    $pos--; # go back a character; we've encountered a non-type character
    # Type name is done
    $typeLen = $pos - $typeStart; 
    # do something with the type
    my $info = $handlers->{ substr( $data, $typeStart, $typeLen ) };
    my $handler = $info->[0];
    my $htype = $info->[1];
    if( !$handler ) {
        print("disaster");
        exit(1);
    }
    my $res = $handler->( $data, $pos );
    if( !$res ) {
        print("disaster");
        exit(1);
    }
    if( !$res->{dest} ) {
        if( $cur->{_type} == 1 ) {
            $cur->{ substr( $data, $keyStart, $keyLen ) } = $res->{node};
            goto AfterVal;
        }
        if( $cur->{_type} == 3 ) {
            push( @{$cur->{arr}}, $res->{node} );
            goto AfterColon;
        }
    }
    goto TypeX; # should never reach here
Arr: 
    goto Done if( $pos >= $len );
    $let = substr( $data, $pos++, 1 );
    # TODO: stack of array tails
    if( $let eq ']' ) {
        goto AfterVal;
    }
    goto Arr;
AC_Comment: 
    goto Done if( $pos >= $len );
    $let = substr( $data, $pos++, 1 );
    if( $let eq "\x0d" || $let eq "\x0a" ) { goto AfterColon; }
    goto AC_Comment;
AC_Comment2: 
    goto Done if( $pos >= $len );
    $let = substr( $data, $pos++, 1 );
    if( $let eq '*' && $pos < ($len-1) && substr( $data, $pos, 1 ) eq '/' ) { $pos++; goto Hash; }
    goto AC_Comment2;
Number1: 
    goto Done if( $pos >= $len );
    $let = substr( $data, $pos, 1 );
    $strStart = $pos-1;
NumberX: 
    goto Done if( $pos >= $len );
    $let = substr( $data, $pos++, 1 );
    #if( $let eq '.' ) goto AfterDot;
    if( ord($let) < ord('0') || ord($let) > ord('9') ) {
        my $strLen = ( $pos-1 ) - $strStart;
        my $num = substr( $data, $strStart, $strLen ) * 1;
        $num *= -1 if( $neg );
        if( $cur->{_type} == 1 ) {
            $cur->{ substr( $data, $keyStart, $keyLen ) } = $num;
            goto AfterVal;
        }
        if( $cur->{_type} == 3 ) {
            push( @{$cur->{arr}}, $num );
            goto AfterColon;
        }
    }
    goto NumberX;
#AfterDot: SAFEGET
String1: 
    goto Done if( $pos >= $len );
    $let = substr( $data, $pos++, 1 );
    if( $let eq '"' ) {
        if( $cur->{_type} == 1 ) {
            $cur->{ substr( $data, $keyStart, $keyLen ) } = "";
            goto AfterVal;
        }
        if( $cur->{_type} == 3 ) {
            push( @{$cur->{arr}}, "" );
            goto AfterColon;
        }
        goto AfterVal; # Should never be reached
    }
    $strStart = $pos-1;
StringX: 
    goto Done if( $pos >= $len );
    $let = substr( $data, $pos++, 1 );
    if( $let eq '"' ) {
       my $strLen = ($pos-1) - $strStart;
       my $newStr = substr( $data, $strStart, $strLen );
       if( $cur->{_type} == 1 ) {
           $cur->{ substr( $data, $keyStart, $keyLen ) } = $newStr;
           goto AfterVal;
       }
       if( $cur->{_type} == 3 ) {
           push( @{$cur->{arr}}, $newStr );
           goto AfterColon;
       }
       goto AfterVal; # should never be reached
    }
    goto StringX;   
AfterVal:
    # who cares about commas in between things; we can just ignore them :D
    goto Hash;
Done:
    return $root;
}

1;