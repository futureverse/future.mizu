spelling:
	Rscript -e "spelling::spell_check_package()"
	Rscript -e "spelling::spell_check_files(c('NEWS.md'))"

future.tests:
	Rscript -e "future.tests::check(plan = 'future.mizu::mizu_multisession')"
