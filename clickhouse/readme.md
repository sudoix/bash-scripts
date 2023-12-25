#### total_row.sh

This Bash script connects to a ClickHouse database server using provided connection details and retrieves a list of databases. It then iterates through each database, obtaining a list of tables within each database and counting the rows in each table. The script accumulates the row counts and calculates the total size of all databases combined. Finally, it calculates the ratio of the grand total row count to the total size, providing a metric that represents the relationship between the total number of rows and the size of the databases.

