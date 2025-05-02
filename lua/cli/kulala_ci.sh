install_dependencies() {
  echo "Installing JQ ===================================="
  sudo apt-get -y install jq
  # curl, grpcurl, websocat, nvim-treesitter
}

echo "RUNNING KULALA CI ===================================="
install_dependencies
