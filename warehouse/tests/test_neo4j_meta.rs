mod support;

use anyhow::Result;
// use libra_warehouse::table_structs::WarehouseTxMaster;
use neo4rs::{query, Graph, Node};
use support::neo4j_testcontainer::start_neo4j_container;

/// get a
pub async fn make_driver(port: u16) -> Result<Graph> {
    let uri = format!("127.0.0.1:{port}");
    let user = "neo4j";
    let pass = "neo";
    Ok(Graph::new(uri, user, pass).await?)
}

// pub async fn connect_neo4j(port: u16) {
//     let graph = make_driver(port).await;

//     let mut txn = graph.start_txn().await.unwrap();

//     txn.run_queries([
//         "MERGE (p:Person {name: 'alice', id: 123 })",
//         "MERGE (p:Person {name: 'bob', id: 456 })",
//         "MERGE (p:Person {name: 'carol', id: 789 })",
//     ])
//     .await
//     .unwrap();
//     txn.commit().await.unwrap();

//     let mut result = graph
//         .execute(query("MATCH (p:Person {name: $this_name}) RETURN p").param("this_name", "alice"))
//         .await
//         .unwrap();
//     while let Ok(Some(row)) = result.next().await {
//         let node: Node = row.get("p").unwrap();
//         let id: u64 = node.get("id").unwrap();
//         assert!(id == 123);
//     }

// }

#[tokio::test]
async fn test_neo4j_connect() -> Result<()> {
    let c = start_neo4j_container();
    let port = c.get_host_port_ipv4(7687);
    let graph = make_driver(port).await?;

    let mut txn = graph.start_txn().await.unwrap();

    txn.run_queries([
        "MERGE (p:Person {name: 'alice', id: 123 })",
        "MERGE (p:Person {name: 'bob', id: 456 })",
        "MERGE (p:Person {name: 'carol', id: 789 })",
    ])
    .await
    .unwrap();
    txn.commit().await.unwrap();

    let mut result = graph
        .execute(query("MATCH (p:Person {name: $this_name}) RETURN p").param("this_name", "alice"))
        .await
        .unwrap();
    while let Ok(Some(row)) = result.next().await {
        let node: Node = row.get("p").unwrap();
        let id: u64 = node.get("id").unwrap();
        assert!(id == 123);
    }

    Ok(())
}

#[tokio::test]
async fn test_tx_insert() -> Result<()> {
    let c = start_neo4j_container();
    let port = c.get_host_port_ipv4(7687);
    let graph = make_driver(port).await?;

    let mut txn = graph.start_txn().await.unwrap();

    txn.run_queries([
      "MERGE (from:Account {address: 'alice'})-[r:Tx {txs_hash: '0000000'}]->(to:Account {address: 'bob'})"
    ]).await.unwrap();
    txn.commit().await.unwrap();

    let mut result = graph
        .execute(query(
            "MATCH p=()-[:Tx {txs_hash: '0000000'}]->() RETURN p",
        ))
        .await?;
    let mut found_rows = 0;
    while let Ok(Some(row)) = result.next().await {
        found_rows += 1;
    }
    assert!(found_rows == 1);

    let mut result = graph
        .execute(query("MATCH (p:Account {address: 'alice'}) RETURN p"))
        .await?;
    while let Ok(Some(row)) = result.next().await {
        let node: Node = row.get("p").unwrap();
        let id: String = node.get("address").unwrap();
        assert!(id == "alice".to_owned());
    }

    Ok(())
}
