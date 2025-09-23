default:
    just --list



dive-inspect:
  gunzip --stdout result > /tmp/image.tar && dive docker-archive:///tmp/image.tar