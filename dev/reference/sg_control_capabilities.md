# Control service capabilities (segmantR-control-v1)

The local control service lets a partner (qupflowR, annotatR) drive a
running segmantR app through typed commands. It is **planned** and not
implemented; this function reports the planned contract so partners can
check for it without guessing. It never starts a server.

## Usage

``` r
sg_control_capabilities()
```

## Value

A list with `schema`, `status` (`"planned"`), `implemented` (`FALSE`),
`default` (`"off"`), `planned_commands` and `security_requirements`.

## Examples

``` r
sg_control_capabilities()$status
#> [1] "planned"
```
