# stagemap 0.0.0.9000

* `stagemap()` builds a map object from nodes and links data frames and checks them, naming the rows that are wrong (#13).
* `sm_groups()` sets group colours and legend labels (#14).
* `sm_kind()` describes a link's line, colour, width, arrow and middle mark (#14).
* `sm_kinds()` sets and combines styles for named link kinds (#14).
* `sm_layout()` sets the direction, the order of nodes within a stage and the spacing; the layout is computed in R and is the same on every run (#15).
* `sm_lanes()` sets lane order, including empty bands (#14).
* `sm_stages()` sets stage order, including empty columns (#14).
* `sm_status()` sets badge text for built-in and custom status words (#14).
* `sm_svg()` writes a map as an SVG image, or returns it as text, drawn in R with no extra packages, in a light or dark theme (#16).
