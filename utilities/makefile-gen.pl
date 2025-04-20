#!/usr/bin/perl

# Generates Makefile for each benchmark in polybench
# Expects to be executed from root folder of polybench
#
# Written by Tomofumi Yuki, 11/21 2014
#

my $GEN_CONFIG = 0;
my $TARGET_DIR = ".";

if ($#ARGV !=0 && $#ARGV != 1) {
   printf("usage perl makefile-gen.pl output-dir [-cfg]\n");
   printf("  -cfg option generates config.mk in the output-dir.\n");
   exit(1);
}



foreach my $arg (@ARGV) {
   if ($arg =~ /-cfg/) {
      $GEN_CONFIG = 1;
   } elsif (!($arg =~ /^-/)) {
      $TARGET_DIR = $arg;
   }
}


my %categories = (
   'linear-algebra/blas' => 3,
   'linear-algebra/kernels' => 3,
   'linear-algebra/solvers' => 3,
   'datamining' => 2,
   'stencils' => 2,
   'medley' => 2
);

my %extra_flags = (
   'cholesky' => '-lm',
   'gramschmidt' => '-lm',
   'correlation' => '-lm'
);

foreach $key (keys %categories) {
   my $target = $TARGET_DIR.'/'.$key;
   opendir DIR, $target or die "directory $target not found.\n";
   while (my $dir = readdir DIR) {
        next if ($dir=~'^\..*');
        next if (!(-d $target.'/'.$dir));

	my $kernel = $dir;
        my $file = $target.'/'.$dir.'/Makefile';
        my $polybenchRoot = '../'x$categories{$key};
        my $configFile = $polybenchRoot.'config.mk';
        my $utilityDir = $polybenchRoot.'utilities';

        open FILE, ">$file" or die "failed to open $file.";

print FILE << "EOF";
include $configFile

EXTRA_FLAGS=$extra_flags{$kernel}

$kernel: $kernel.c tb_$kernel.c $kernel.h
	\${VERBOSE} \${CC} -o $kernel $kernel.c \${CFLAGS} -I. -I$utilityDir $utilityDir/polybench.c \${EXTRA_FLAGS}

hls: $kernel.c tb_$kernel.c $kernel.h
	\${VERBOSE} vitis_hls hls.tcl

clean:
	@ rm -f $kernel

EOF

        close FILE;

        my $hls_file = $target.'/'.$dir.'/hls.tcl';
        my $prj_name = $kernel;
        $prj_name =~ s/-/_/g;

        open FILE, ">$hls_file" or die "failed to open $file.";
        
print FILE << "EOF";
open_project ${prj_name}_syn

source ${polybenchRoot}config.tcl
set global_cflags "-I[pwd]/${polybenchRoot}utilities \$polybench_cflags"

add_files $kernel.c -cflags "\$global_cflags"
add_files -tb "tb_$kernel.c [pwd]/${polybenchRoot}utilities/polybench.c" -cflags "\$global_cflags"

set_top kernel_${prj_name}

open_solution -reset solution
set_part {xc7vx690tffg1930-3}
create_clock -period 10

csim_design
csynth_design
cosim_design -rtl verilog
export_design -flow impl -rtl verilog -format ip_catalog

exit
EOF

        close FILE;
   }


   closedir DIR;
}

if ($GEN_CONFIG) {
open FILE, '>'.$TARGET_DIR.'/config.mk';

print FILE << "EOF";
CC=gcc
CFLAGS=-O2 -std=gnu11 -DPOLYBENCH_DUMP_ARRAYS -DPOLYBENCH_USE_C99_PROTO -DPOLYBENCH_USE_RESTRICT
EOF

close FILE;

open FILE, '>'.$TARGET_DIR.'/config.tcl';

print FILE << "EOF";
set polybench_cflags "-std=gnu11 -DMINI_DATASET -DPOLYBENCH_USE_RESTRICT"
EOF

close FILE;

}

