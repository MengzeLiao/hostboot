#!/usr/bin/perl
# IBM_PROLOG_BEGIN_TAG
# This is an automatically generated prolog.
#
# $Source: src/usr/fapi2/platCreateHwpErrParser.pl $
#
# OpenPOWER HostBoot Project
#
# Contributors Listed Below - COPYRIGHT 2015,2016
# [+] International Business Machines Corp.
#
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied. See the License for the specific language governing
# permissions and limitations under the License.
#
# IBM_PROLOG_END_TAG

#
# Purpose:  This perl script will parse HWP Error XML files and create a
#           file containing functions that parses the return code and FFDC
#           data in HWP error logs
#
# Author: Thi Tran
#

use strict;

#------------------------------------------------------------------------------
# Print Command Line Help
#------------------------------------------------------------------------------
my $numArgs = $#ARGV + 1;
if ($numArgs < 2)
{
    print ("Usage: platCreateHwpErrParser.pl <output dir> <filename1> <filename2> ...\n");
    print ("  This perl script will parse HWP Error XML files and create\n");
    print ("  a file called fapiPlatHwpErrParser.H that contains functions to\n");
    print ("  parse the return code and FFDC data in HWP error logs\n");
    exit(1);
}

#------------------------------------------------------------------------------
# Specify perl modules to use
#------------------------------------------------------------------------------
use Digest::MD5 qw(md5_hex);
use XML::Simple;
my $xml = new XML::Simple (KeyAttr=>[]);

# Uncomment to enable debug output
#use Data::Dumper;

#------------------------------------------------------------------------------
# Open output files for writing
#------------------------------------------------------------------------------
my $rcFile = $ARGV[0];
$rcFile .= "/";
$rcFile .= "platHwpErrParser.H";
open(TGFILE, ">", $rcFile);

#------------------------------------------------------------------------------
# Print start of file information
#------------------------------------------------------------------------------
print TGFILE "// platHwpErrParser.H\n";
print TGFILE "// This file is generated by perl script platCreateHwpErrParser.pl\n\n";
print TGFILE "#ifndef PLATHWPERRPARSER_H_\n";
print TGFILE "#define PLATHWPERRPARSER_H_\n\n";
print TGFILE "#ifdef PARSER\n\n";
print TGFILE "namespace fapi2\n";
print TGFILE "{\n\n";
print TGFILE "void parseHwpRc(ErrlUsrParser & i_parser,\n";
print TGFILE "                    void * i_pBuffer,\n";
print TGFILE "                    const uint32_t i_buflen)\n";
print TGFILE "{\n";
print TGFILE "        uint32_t l_rc = ntohll(*(static_cast<uint32_t *>(i_pBuffer)));\n";
print TGFILE "    switch(l_rc)\n";
print TGFILE "    {\n";

#------------------------------------------------------------------------------
# For each XML file
#------------------------------------------------------------------------------
foreach my $argnum (1 .. $#ARGV)
{
    #--------------------------------------------------------------------------
    # Read XML file
    #--------------------------------------------------------------------------
    my $infile = $ARGV[$argnum];
    my $errors = $xml->XMLin($infile, ForceArray => ['hwpError']);

    # Uncomment to get debug output of all errors
    #print "\nFile: ", $infile, "\n", Dumper($errors), "\n";

    #--------------------------------------------------------------------------
    # For each Error
    #--------------------------------------------------------------------------
    foreach my $err (@{$errors->{hwpError}})
    {
        #----------------------------------------------------------------------
        # Get the description, remove newlines, leading and trailing spaces and
        # multiple spaces
        #----------------------------------------------------------------------
        my $desc = $err->{description};
        $desc =~ s/\n/ /g;
        $desc =~ s/^ +//g;
        $desc =~ s/ +$//g;
        $desc =~ s/ +/ /g;
        $desc =~ s/\"//g;

        #----------------------------------------------------------------------
        # Print the RC description
        # Note that this uses the same code to calculate the error enum value
        # as fapiParseErrorInfo.pl. This code must be kept in sync
        #----------------------------------------------------------------------
        my $errHash128Bit = md5_hex($err->{rc});
        my $errHash24Bit = substr($errHash128Bit, 0, 6);

        print TGFILE "    case 0x$errHash24Bit:\n";
        print TGFILE "        i_parser.PrintString(\"HwpReturnCode\", \"$err->{rc}\");\n";
        print TGFILE "        i_parser.PrintString(\"HWP Error description\", \"$desc\");\n";
        print TGFILE "        break;\n";
    }
}

#------------------------------------------------------------------------------
# Print end of fapiParseHwpRc function
#------------------------------------------------------------------------------
print TGFILE "    default:\n";
print TGFILE "        i_parser.PrintNumber(\"Unrecognized Error ID\", \"0x%x\", l_rc);\n";
print TGFILE "    }\n";
print TGFILE "}\n\n";

#------------------------------------------------------------------------------
# Print start of fapiParseHwpFfdc function
#------------------------------------------------------------------------------
print TGFILE "void parseHwpFfdc(ErrlUsrParser & i_parser,\n";
print TGFILE "                  void * i_pBuffer,\n";
print TGFILE "                  const uint32_t i_buflen)\n";
print TGFILE "{\n";
print TGFILE "    const uint32_t CFAM_DATA_LEN = 4;\n";
print TGFILE "    const uint32_t SCOM_DATA_LEN = 8;\n";
print TGFILE "    const uint32_t POS_LEN = 4;\n";
print TGFILE "    uint8_t * l_pBuffer = static_cast<uint8_t *>(i_pBuffer);\n";
print TGFILE "    uint32_t l_buflen = i_buflen;\n\n";
print TGFILE "    // The first uint32_t is the FFDC ID\n";
print TGFILE "    uint32_t * l_pFfdcId = static_cast<uint32_t *>(i_pBuffer);\n";
print TGFILE "    uint32_t l_ffdcId = ntohl(*l_pFfdcId);\n";
print TGFILE "    l_pBuffer += sizeof(l_ffdcId);\n";
print TGFILE "    l_buflen -= sizeof(l_ffdcId);\n";
print TGFILE "    switch(l_ffdcId)\n";
print TGFILE "    {\n";

#------------------------------------------------------------------------------
# For each XML file
#------------------------------------------------------------------------------
foreach my $argnum (1 .. $#ARGV)
{
    #--------------------------------------------------------------------------
    # Read XML file
    #--------------------------------------------------------------------------
    my $infile = $ARGV[$argnum];
    my $errors = $xml->XMLin($infile, ForceArray =>
        ['hwpError', 'ffdc', 'registerFfdc', 'cfamRegister', 'scomRegister']);

    # Uncomment to get debug output of all errors
    #print "\nFile: ", $infile, "\n", Dumper($errors), "\n";

    #--------------------------------------------------------------------------
    # If it is an FFDC section resulting from a <hwpError><ffdc> element, print
    # out the FFDC name and hexdump the data
    #--------------------------------------------------------------------------
    foreach my $err (@{$errors->{hwpError}})
    {
        foreach my $ffdc (@{$err->{ffdc}})
        {
            #------------------------------------------------------------------
            # Figure out the FFDC ID stored in the data. This is calculated in
            # the same way as fapiParseErrorInfo.pl. This code must be kept in
            # sync
            #------------------------------------------------------------------
            my $ffdcName = $err->{rc} . "_" . $ffdc;
            my $ffdcHash128Bit = md5_hex($ffdcName);
            my $ffdcHash32Bit = substr($ffdcHash128Bit, 0, 8);

            print TGFILE "    case 0x$ffdcHash32Bit:\n";
            print TGFILE "        i_parser.PrintString(\"HwpReturnCode\", \"$err->{rc}\");\n";
            print TGFILE "        i_parser.PrintString(\"FFDC:\", \"$ffdc\");\n";
            print TGFILE "        if (l_buflen) ";
            print TGFILE "{i_parser.PrintHexDump(l_pBuffer, l_buflen);}\n";
            print TGFILE "        break;\n";
        }
    }

    #--------------------------------------------------------------------------
    # If it is an FFDC section resulting from a <registerFfdc> element, print
    # out the ID and walk through the registers, printing each out
    #--------------------------------------------------------------------------
    foreach my $registerFfdc (@{$errors->{registerFfdc}})
    {
        #----------------------------------------------------------------------
        # Figure out the FFDC ID stored in the data. This is calculated in the
        # same way as fapiParseErrorInfo.pl. This code must be kept in sync
        #----------------------------------------------------------------------
        my $ffdcName = $registerFfdc->{id};
        my $ffdcHash128Bit = md5_hex($ffdcName);
        my $ffdcHash32Bit = substr($ffdcHash128Bit, 0, 8);
        print TGFILE "    case 0x$ffdcHash32Bit:\n";
        print TGFILE "        i_parser.PrintString(\"Register FFDC:\", \"$ffdcName\");\n";
        print TGFILE "        while (l_buflen > 0)\n";
        print TGFILE "        {\n";
        print TGFILE "            if (l_buflen >= POS_LEN)\n";
        print TGFILE "            {\n";
        print TGFILE "                uint32_t * l_pBufferTemp = reinterpret_cast<uint32_t *>(l_pBuffer);\n";
        print TGFILE "                i_parser.PrintNumber(\"Chip Position:\",\"%X\",ntohl(*l_pBufferTemp));\n";
        print TGFILE "                l_pBufferTemp = NULL;\n";
        print TGFILE "                l_pBuffer+= POS_LEN;\n";
        print TGFILE "                l_buflen -= POS_LEN;\n";
        print TGFILE "            }\n";
        foreach my $cfamRegister (@{$registerFfdc->{cfamRegister}})
        {
            print TGFILE "            if (l_buflen >= CFAM_DATA_LEN)\n";
            print TGFILE "            {\n";
            print TGFILE "                i_parser.PrintString(\"CFAM Register:\", \"$cfamRegister\");\n";
            print TGFILE "                i_parser.PrintHexDump(l_pBuffer, CFAM_DATA_LEN);\n";
            print TGFILE "                l_pBuffer+= CFAM_DATA_LEN;\n";
            print TGFILE "                l_buflen -= CFAM_DATA_LEN;\n";
            print TGFILE "            }\n";
        }
        foreach my $scomRegister (@{$registerFfdc->{scomRegister}})
        {

            print TGFILE "            if (l_buflen >= SCOM_DATA_LEN)\n";
            print TGFILE "            {\n";
            print TGFILE "                i_parser.PrintString(\"SCOM Register:\", \"$scomRegister\");\n";
            print TGFILE "                i_parser.PrintHexDump(l_pBuffer, SCOM_DATA_LEN);\n";
            print TGFILE "                l_pBuffer+= SCOM_DATA_LEN;\n";
            print TGFILE "                l_buflen -= SCOM_DATA_LEN;\n";
            print TGFILE "            }\n";
        }
        print TGFILE "        }\n";
        print TGFILE "        break;\n";
    }
}

#------------------------------------------------------------------------------
# Print end of parseHwpFfdc function
#------------------------------------------------------------------------------
print TGFILE "    default:\n";
print TGFILE "        i_parser.PrintNumber(\"Unrecognized FFDC\", \"0x%x\", l_ffdcId);\n";
print TGFILE "        if (l_buflen) ";
print TGFILE "{i_parser.PrintHexDump(l_pBuffer, l_buflen);}\n";
print TGFILE "    }\n\n";
print TGFILE "}\n\n";

#------------------------------------------------------------------------------
# Print end of file info
#------------------------------------------------------------------------------
print TGFILE "}\n\n";
print TGFILE "#endif\n";
print TGFILE "#endif\n";

#------------------------------------------------------------------------------
# Close output file
#------------------------------------------------------------------------------
close(TGFILE);

