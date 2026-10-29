Minimal, valid snippets used to pre-compile the tree-sitter parser
objects at image build time, and to verify in the finished image that every
grammar parses without a C compiler present.

scopes.txt maps each tree-sitter scope to its sample file. The five scopes
ParSitter asks for come from its languages/*.toml; source.js is here only
because the javascript grammar is kept for future use.
