use Module::Build;

Module::Build->new(
    module_name		=> "BMORROW::MooX::Misc",
    license		=> "bsd",
    configure_requires	=> {
	"Module::Build"	    => "0.38",
    },
    build_requires	=> {
	"Test::More"	    => "0.96",
    },
    requires            => {
        "Data::Dump"            => "0",
        "Module::Runtime"       => "0",
        "Moo"                   => "0",
        "MooX::CaptainHook"     => "0",
        "Regexp::Common"        => "0",
        "namespace::clean"      => "0",
    },
    meta_merge		=> {
	resources   => {
	    repository => "http://github.com/mauzo/BMORROW-MooX-Misc",
	    bugtracker => "https://rt.cpan.org/Public/Dist/" .
		"Display.html?Name=BMORROW-MooX-Misc",
	},
    },
)->create_build_script;
