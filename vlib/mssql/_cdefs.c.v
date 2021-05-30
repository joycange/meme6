module mssql

// [typedef]
// struct C.SQLHENV { // Environment
// }

// [typedef]
// struct C.SQLHDBC { // Connection handle
// }

// [typedef]
// struct C.SQLHSTMT { // Statement handle
// }

// [typedef]
// struct C.SQLRETURN {
// }

// [typedef]
// struct C.SQLCHAR {
// }

// [typedef]
// struct C.SQLSMALLINT {
// }

fn C.SQLAllocHandle(HandleType C.SQLSMALLINT, InputHandle C.SQLHANDLE, OutputHandle &C.SQLHANDLE) C.SQLRETURN

fn C.SQLSetEnvAttr(EnvironmentHandle C.SQLHENV, Attribute C.SQLINTEGER, Value C.SQLPOINTER, StringLength C.SQLINTEGER) C.SQLRETURN

fn C.SQLGetDiagRec(HandleType C.SQLSMALLINT, Handle C.SQLHANDLE,
							RecNumber C.SQLSMALLINT, Sqlstate &C.SQLCHAR,
							NativeError &C.SQLINTEGER, MessageText &C.SQLCHAR,
							BufferLength C.SQLSMALLINT, TextLength &C.SQLSMALLINT) C.SQLRETURN

fn C.SQLSetConnectAttr(ConnectionHandle C.SQLHDBC,
						Attribute C.SQLINTEGER, Value C.SQLPOINTER,
						StringLength C.SQLINTEGER) C.SQLRETURN
		
fn C.SQLDriverConnect(
    hdbc C.SQLHDBC                  ,
    hwnd C.SQLHWND                  ,
    szConnStrIn &C.SQLCHAR 		    ,
    cbConnStrIn C.SQLSMALLINT       ,
    szConnStrOut &C.SQLCHAR         ,
    cbConnStrOutMax C.SQLSMALLINT   ,
    pcbConnStrOut &C.SQLSMALLINT 	,
    fDriverCompletion C.SQLUSMALLINT) C.SQLRETURN

fn C.SQLDisconnect(ConnectionHandle C.SQLHDBC) C.SQLRETURN

fn C.SQLExecDirect(StatementHandle C.SQLHSTMT,
                        	StatementText &C.SQLCHAR, TextLength C.SQLINTEGER) C.SQLRETURN

fn C.SQLBindCol(StatementHandle C.SQLHSTMT,
				ColumnNumber C.SQLUSMALLINT, TargetType C.SQLSMALLINT,
				TargetValue C.SQLPOINTER, BufferLength C.SQLLEN,
				StrLen_or_Ind &C.SQLLEN) C.SQLRETURN

fn C.SQLFetch(StatementHandle C.SQLHSTMT) C.SQLRETURN

fn C.SQLFreeHandle(HandleType C.SQLSMALLINT, Handle C.SQLHANDLE) C.SQLRETURN