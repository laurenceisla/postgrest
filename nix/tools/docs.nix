{ buildToolbox
, checkedShellScript
, python3
, aspell
, aspellDicts
}:
let
  python = python3.withPackages (ps: [
    ps.sphinx
    ps.sphinx_rtd_theme
    ps.livereload
    ps.sphinx-tabs
    ps.sphinx-copybutton
    ps.sphinxext-opengraph
  ]);

  build =
    checkedShellScript
      {
        name = "postgrest-docs-build";
        docs = "Clean and build the documentation.";
        inDocsDir = true;
      }
      ''
        # clean previous build, otherwise some errors might be supressed
        rm -rf _build

        ${python}/bin/sphinx-build --color -W -b html -a -n docs _build
      '';

  serve =
    checkedShellScript
      {
        name = "postgrest-docs-serve";
        docs = "Serve the documentation locally with live reload.";
        inDocsDir = true;
      }
      ''
        # livereload_docs.py needs to find "sphinx-build"
        PATH=${python}/bin:$PATH

        ${python}/bin/python livereload_docs.py
      '';

  spellcheck =
    checkedShellScript
      {
        name = "postgrest-docs-spellcheck";
        docs = "Verify spelling mistakes. Bypass if the word is present in postgrest.dict";
        inDocsDir = true;
      }
      ''
        FILES=$(find docs -type f -iname '*.rst' | tr '\n' ' ')

        # shellcheck disable=SC2016
        # shellcheck disable=SC2002
        # shellcheck disable=SC2086
        cat $FILES \
         | grep -v '^\(\.\.\|  \)' \
         | sed 's/`.*`//g' \
         | ${aspell}/bin/aspell -d ${aspellDicts.en}/lib/aspell/en_US -p ./postgrest.dict list \
         | sort -f \
         | tee misspellings
        test ! -s misspellings
      '';

  dictcheck =
    checkedShellScript
      {
        name = "postgrest-docs-dictcheck";
        docs = "Detect obsolete entries in postgrest.dict that are not used anymore.";
        inDocsDir = true;
      }
      ''
        FILES=$(find docs -type f -iname '*.rst' | tr '\n' ' ')

        # shellcheck disable=SC2002
        cat postgrest.dict \
         | tail -n+2 \
         | tr '\n' '\0' \
         | xargs -0 -n 1 -i \
           sh -c "grep \"{}\" $FILES > /dev/null || echo \"{}\"" \
         | tee unuseddict
        test ! -s unuseddict
      '';

  linkcheck =
    checkedShellScript
      {
        name = "postgrest-docs-linkcheck";
        docs = "Verify that external links are working correctly.";
        inDocsDir = true;
      }
      ''
        ${python}/bin/sphinx-build --color -b linkcheck docs _build
      '';

  check =
    checkedShellScript
      {
        name = "postgrest-docs-check";
        docs = "Build and run all the validation scripts.";
        inDocsDir = true;
      }
      ''
        ${build}/bin/postgrest-docs-build
        ${dictcheck}/bin/postgrest-docs-dictcheck
        ${linkcheck}/bin/postgrest-docs-linkcheck
        ${spellcheck}/bin/postgrest-docs-spellcheck
      '';

in
buildToolbox
{
  name = "postgrest-docs";
  tools =
    [
      build
      serve
      spellcheck
      dictcheck
      linkcheck
      check
    ];
}
