#!/bin/bash
# Bootstrap an R/travis environment.

set -e

Bootstrap() {
  OS=$(uname -s)
  if [ "Darwin" == "${OS}" ]; then
    BootstrapMac
  elif [ "Linux" == "${OS}" ]; then
    BootstrapLinux
  else
    echo "Unknown OS: ${OS}"
    exit 1
  fi
}

BootstrapLinux() {
  # Add RStudio's CRAN repository
  echo -e "deb http://cran.rstudio.com/bin/linux/ubuntu precise/\ndeb-src http://cran.rstudio.com/bin/linux/ubuntu precise/" > /etc/apt/sources.list.d/cran.list
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E084DAB9
  apt-get update -o Dir::Etc::sourcelist="sources.list.d/cran.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"

  # Add Michael Rutter's c2d4u repository
  apt-add-repository -y ppa:marutter/c2d4u
  apt-get update -o Dir::Etc::sourcelist="sources.list.d/marutter-c2d4u-precise.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"

  # Install recommended R packages, and LaTeX
  apt-get install --no-install-recommends r-base-dev r-cran-xml r-cran-rcurl r-recommended $extra_packages
}

BootstrapMac() {
  # TODO(craigcitro): Figure out TeX in OSX+travis.

  # Install R.
  brew install r
}

BootstrapDevTools() {
  # Create fresh site library
  rm -rf $R_LIBS_USER
  mkdir $R_LIBS_USER

  # Install devtools & bootstrap to github version
  R --slave --vanilla <<EOF_R
    install.packages(c("devtools"), repos=c("http://cran.rstudio.com"))
    library(devtools)
    install_github("devtools")
EOF_R
}

GithubPackage() {
  # An embarrassingly awful script for calling install_github from a
  # .travis.yml.
  #
  # Note that bash quoting makes this annoying for any additional
  # arguments.

  # Get the package name and strip it
  PACKAGE_NAME=$1
  shift
  
  # Join the remaining args.
  ARGS=$(echo $* | sed -e 's/ /, /g')
  if [ -n "${ARGS}" ]; then
    ARGS=", ${ARGS}"
  fi

  echo "Installing package: ${PACKAGE_NAME}"
  # Install the package.
  R --slave --vanilla <<EOF_R
    library(devtools)
    options(repos = c(CRAN = "http://cran.rstudio.com"))
    install_github("${PACKAGE_NAME}"${ARGS})
EOF_R
}

InstallDeps() {
  R --slave --vanilla <<EOF_R
    library(devtools)
    options(repos = c(CRAN = "http://cran.rstudio.com"))
    devtools:::install_deps(dependencies = TRUE)
EOF_R
}

RunTests() {
  R CMD build $build_vignettes .
  FILE=$(ls -1 *.tar.gz)
  R CMD check "${FILE}" $manual --as-cran
  exit $?
}

mode=stable
export R_LIBS_USER=$HOME/R-$mode

RTRAVISTYPE=quick
echo "RTRAVISTYPE: $RTRAVISTYPE" >> /dev/stderr
case "$RTRAVISTYPE" in
    quick) modes=stable; build_vignettes=--no-build-vignettes; export manual=--no-manual; true;;
    full | "") modes="stable devel"; extra_packages="qpdf texinfo texlive-latex-recommended texlive-latex-extra lmodern texlive-fonts-recommended texlive-fonts-extra"; true;;
    *) echo "Unsupported RTRAVISTYPE." >> /dev/stderr; false;;
esac || exit 1

COMMAND=$1
echo "Running command ${COMMAND}"
shift
case $COMMAND in
  "bootstrap")
    Bootstrap
    ;;
  "bootstrap_devtools")
    BootstrapDevTools
    ;;
  "github_package")
    GithubPackage "$*"
    ;;
  "install_deps")
    InstallDeps
    ;;
  "run_tests")
    RunTests
    ;;
esac
