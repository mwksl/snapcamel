# Use the official OCaml opam image
FROM ocaml/opam:debian-11-ocaml-4.14

# Install system dependencies
RUN sudo apt-get update && sudo apt-get install -y \
    libgmp-dev \
    libssl-dev \
    libsqlite3-dev \
    pkg-config \
    libev-dev \
    bash

# Switch to opam user
USER opam

# Set the working directory
WORKDIR /home/opam/app

# Copy project files
COPY --chown=opam . /home/opam/app

# Set the shell to bash
SHELL ["/bin/bash", "-c"]

# Install opam dependencies and build the project in a single RUN command
RUN opam install . --deps-only -y && \
    eval $(opam env) && \
    dune build

# Expose the port
EXPOSE 8080

# Set environment variables for runtime
ENV PATH="/home/opam/.opam/default/bin:${PATH}"
ENV OCAML_TOPLEVEL_PATH="/home/opam/.opam/default/lib/toplevel"

# Command to run the application
CMD ["dune", "exec", "--", "./src/main.exe"]
