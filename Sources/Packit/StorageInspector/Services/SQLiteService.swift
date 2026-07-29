import Foundation
import SQLite3

public struct SQLiteTable: Identifiable {
    public let id = UUID()
    public let name: String
    public let rowCount: Int
}

public struct SQLiteColumn: Identifiable {
    public let id = UUID()
    public let name: String
    public let type: String
}

public struct SQLiteRow: Identifiable {
    public let id = UUID()
    public let data: [String: String]
}

public class SQLiteService {
    private var db: OpaquePointer?
    private let url: URL
    
    public init(url: URL) {
        self.url = url
    }
    
    deinit {
        close()
    }
    
    public func open() -> Bool {
        if sqlite3_open(url.path, &db) == SQLITE_OK {
            return true
        } else {
            print("Unable to open database at \(url.path)")
            return false
        }
    }
    
    public func close() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }
    
    public func getTables() -> [SQLiteTable] {
        guard let db = db else { return [] }
        
        let query = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
        var statement: OpaquePointer?
        
        var tables: [SQLiteTable] = []
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let cString = sqlite3_column_text(statement, 0) {
                    let tableName = String(cString: cString)
                    
                    // Get row count for the table
                    let countQuery = "SELECT COUNT(*) FROM \"\(tableName)\";"
                    var countStmt: OpaquePointer?
                    var rowCount = 0
                    if sqlite3_prepare_v2(db, countQuery, -1, &countStmt, nil) == SQLITE_OK {
                        if sqlite3_step(countStmt) == SQLITE_ROW {
                            rowCount = Int(sqlite3_column_int(countStmt, 0))
                        }
                    }
                    sqlite3_finalize(countStmt)
                    
                    tables.append(SQLiteTable(name: tableName, rowCount: rowCount))
                }
            }
        }
        sqlite3_finalize(statement)
        
        return tables
    }
    
    public func getColumns(for table: String) -> [SQLiteColumn] {
        guard let db = db else { return [] }
        
        let query = "PRAGMA table_info(\"\(table)\");"
        var statement: OpaquePointer?
        
        var columns: [SQLiteColumn] = []
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let nameStr = String(cString: sqlite3_column_text(statement, 1))
                let typeStr = String(cString: sqlite3_column_text(statement, 2))
                columns.append(SQLiteColumn(name: nameStr, type: typeStr))
            }
        }
        sqlite3_finalize(statement)
        
        return columns
    }
    
    public func getRows(for table: String, limit: Int = 100) -> [SQLiteRow] {
        guard let db = db else { return [] }
        
        let columns = getColumns(for: table)
        let query = "SELECT * FROM \"\(table)\" LIMIT \(limit);"
        var statement: OpaquePointer?
        
        var rows: [SQLiteRow] = []
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                var rowData: [String: String] = [:]
                
                for (index, column) in columns.enumerated() {
                    let i = Int32(index)
                    let colType = sqlite3_column_type(statement, i)
                    
                    var valueStr = "NULL"
                    
                    switch colType {
                    case SQLITE_INTEGER:
                        valueStr = String(sqlite3_column_int64(statement, i))
                    case SQLITE_FLOAT:
                        valueStr = String(sqlite3_column_double(statement, i))
                    case SQLITE_TEXT:
                        if let cString = sqlite3_column_text(statement, i) {
                            valueStr = String(cString: cString)
                        }
                    case SQLITE_BLOB:
                        let bytes = sqlite3_column_bytes(statement, i)
                        valueStr = "BLOB (\(bytes) bytes)"
                    case SQLITE_NULL:
                        valueStr = "NULL"
                    default:
                        valueStr = "UNKNOWN"
                    }
                    
                    rowData[column.name] = valueStr
                }
                
                rows.append(SQLiteRow(data: rowData))
            }
        }
        sqlite3_finalize(statement)
        
        return rows
    }
}
