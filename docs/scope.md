# stagemap: scope

stagemap draws **relation maps**: things placed by stage (columns) and, where it helps, by lane (rows), joined by
**typed links** (each kind of link has its own style and a legend entry). R functions answer questions about the map.
This page says what the package is for and what it is not. It is a plan: the data model and the R API are not decided
yet.

## Views

| View | What it shows | Examples |
|---|---|---|
| Column map | Things in fixed columns, joined by typed links | Who built each piece of work and who reviewed it; teams, the services they own and who uses them |
| Traceability map | A chain across stages, with status and gaps flagged | Requirements to functions to tests to results; endpoints to analyses to datasets to outputs; the impact of one changed function |
| Swimlanes | Steps across, lanes down for who does them; links may go backwards | A study's programming flow across teams; question rounds with a health authority; a pull request's path |
| Tree / org chart | Levels as columns, one parent per node | A study's deliverables; adverse events by class and term; a team structure |

Later, from the same data: the map as a matrix (the traceability grid, also the accessible and printable view), a
diff of two versions, a timeline with links between tasks, and a small map inside a table cell.

## Questions answered in code

Trace a node (everything upstream and downstream), find things with no link, coverage (for example, the share of
requirements whose tests passed), the impact of a change, the difference between two versions, cycles. Each returns
a data frame, so it can go into a report or a test.

## Where maps show

Shiny apps (with events and updates from the server), Quarto documents, slides and dashboards, R Markdown, pkgdown
sites, and a static image for PowerPoint, Word and PDF. The package works offline: everything it draws with ships
inside it.

## Not in scope

Force-layout network graphs, sankey and flow quantities, diagram editors (drag to edit), graphs with thousands of
nodes, and CONSORT diagrams (the consort and flowchart packages draw those).

## Who it is for

Shiny developers, Quarto and pkgdown authors, pharma teams documenting validation and traceability, and anyone who
explains who does what across stages.
