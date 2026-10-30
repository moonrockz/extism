# Python Extism qualification fixture

`acme/models.py` and `acme/rules.py` are the loans fixture of the Morphir Python extension, copied from
`apps/morphir/fixtures/extism-python/v1` of finos/morphir-moonbit, which took them from finos/morphir-python
at `0d7e2eb62b4b1249129ab702a5240c41266813f6`. They keep that repository's Apache-2.0 license.
`acme/rules.py` imports `acme/models.py`, so the compile request has two documents.

`mise run qualify:engine` sends them to the Python extension `0.4.2` in a `morphir.frontend.compile` request.
