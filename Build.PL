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
    meta_merge		=> {
	resources   => {
	    repository => "http://github.com/mauzo/BMORROW-MooX-Misc",
	    bugtracker => "https://rt.cpan.org/Public/Dist/" .
		"Display.html?Name=BMORROW-MooX-Misc",
	},
    },
)->create_build_script;
