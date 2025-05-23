/* TBMUMLOT 流程卡生產記錄作業生產明細檔更新回舊模組 */
/* 2023/11/28 jha [20231030001] */
CREATE TRIGGER [dbo].[Trigger_DGF_TBMUMLOT_TO_DG] ON [dbo].[TBMUMLOT]
AFTER INSERT, UPDATE, DELETE 
AS
SET NOCOUNT ON;
DECLARE @workno NVARCHAR(34);
DECLARE @drumno INT;
DECLARE @flow_seq INT;
DECLARE @trxano NVARCHAR(10);
DECLARE @trxano_seq NVARCHAR(3);
DECLARE @seq INT;
/*【MU410】更新前[生產單號、序號] */
DECLARE @trxano_old NVARCHAR(10);
DECLARE @trxano_seq_old NVARCHAR(3);
/*【MU410】更新前[完工日期] */
DECLARE @end_date NVARCHAR(8);
/* 舊模組MU220[領料資料] */
DECLARE @trxcno NVARCHAR(10);
DECLARE @trxcno_seq NVARCHAR(3);
DECLARE @bal_drum_count INT;
DECLARE @bal_wet NUMERIC(10,3);
DECLARE @bal_qty NUMERIC(10,3);
BEGIN TRY
  /* 工令號要移除新模組的前置碼S */
  IF EXISTS (SELECT 1 FROM inserted) 
  BEGIN
   DECLARE inserted_cursor CURSOR FOR
    SELECT A.workno, A.drumno, A.flow_seq, A.trxano, A.trxano_seq, A.print_seq AS seq, 
	       ISNULL(B.trxano, '') AS trxano_old, ISNULL(B.trxano_seq, '') AS trxano_seq_old,
           B.end_date
	FROM inserted A
	LEFT JOIN deleted B ON B.workno = A.workno AND B.drumno = A.drumno AND B.flow_seq = A.flow_seq AND B.print_seq = A.print_seq;
    OPEN inserted_cursor;
    FETCH NEXT FROM inserted_cursor INTO @workno, @drumno, @flow_seq, @trxano, @trxano_seq, @seq, @trxano_old, @trxano_seq_old, @end_date;
    WHILE @@FETCH_STATUS = 0
    BEGIN

      /* 以下同步舊模組【MU220】 */
      /* [生產單號]前置2碼<>"HC"才須同步舊模組 */
      IF LEFT(@trxano, 2) <> 'HC'
      BEGIN
        /* UPDATE，2024/11/19 huei [20241016002]#9 保留MU220原本領料資料  */
        IF EXISTS (SELECT 1 FROM deleted)
        BEGIN
          SELECT @trxcno = trxcno, @trxcno_seq = trxcno_seq, @bal_drum_count = bal_drum_count, @bal_wet = bal_wet, @bal_qty = bal_qty     
          FROM ['+@OLD_DBNAME +'].[dbo].[TBMUMLOT] 
          WHERE workno = SUBSTRING(@workno, 2, LEN(@workno)) AND drumno = @drumno AND trxano = @trxano AND trxano_seq = @trxano_seq AND seq = @seq
        END

        /* INSERT, UPDATE 新資料刪除(確保不重複)，再新增，用CURSOR FOR處理批次異動 */
        DELETE ['+@OLD_DBNAME +'].[dbo].[TBMUMLOT] WHERE workno = SUBSTRING(@workno, 2, LEN(@workno)) AND drumno = @drumno AND 
                                                         trxano = @trxano_old AND trxano_seq = @trxano_seq_old AND seq = @seq
        /* 2024/08/19 huei [20240528001]#3 新的生產單號也執行刪除 確保不會重複 */
        DELETE ['+@OLD_DBNAME +'].[dbo].[TBMUMLOT] WHERE workno = SUBSTRING(@workno, 2, LEN(@workno)) AND drumno = @drumno AND 
                                                         trxano = @trxano AND trxano_seq = @trxano_seq AND seq = @seq
        INSERT INTO ['+@OLD_DBNAME +'].[dbo].[TBMUMLOT] 
        SELECT SUBSTRING(A.workno, 2, LEN(A.workno)) AS workno, A.drumno
               , LEFT(A.trxano, 10) AS trxano, LEFT(A.trxano_seq, 3) AS trxano_seq
               , A.print_seq AS seq
               , A.flow_seq, A.flow, A.flow_desc, A.flow_seq_n, A.flow_n, A.flow_desc_n
               , A.machno_o AS machno, A.trxano_kind AS sect, A.userid, A.userna
               , A.flow_wet
               , CASE WHEN A.drum_a <> 0 THEN A.drum_a WHEN A.drum_b <> 0 THEN A.drum_b ELSE 0 END AS drum_count
               , CASE WHEN A.drum_a <> 0 THEN 'K' WHEN A.drum_b <> 0 THEN 'S' ELSE '' END AS drum_type
               , A.wet, A.qty
               , ISNULL(@bal_drum_count, 0) AS bal_drum_count, ISNULL(@bal_wet, 0) AS bal_wet, ISNULL(@bal_qty, 0) AS bal_qty
               , A.spec_code, A.spec, A.work_desc, A.workno_o
               , ISNULL(@trxcno, '') AS trxcno, ISNULL(@trxcno_seq, '') AS trxcno_seq, A.lotno, A.matr, A.matr_desc
               , LEFT(A.qc_code, 1) AS qc_chk, A.area
               , A.beg_date AS beg_date_c
               , A.end_date AS end_date_c
               , A.createman, A.createdate, A.modifyman, A.modifydate 
	    FROM inserted A
        WHERE A.workno = @workno AND A.drumno = @drumno AND A.trxano = @trxano AND A.trxano_seq = @trxano_seq AND A.print_seq = @seq;
      END
      
      FETCH NEXT FROM inserted_cursor INTO @workno, @drumno, @flow_seq, @trxano, @trxano_seq, @seq, @trxano_old, @trxano_seq_old, @end_date;

    END
    CLOSE inserted_cursor;
    DEALLOCATE inserted_cursor;
  END

  /* DELETE */
    IF NOT EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
      DECLARE deleted_cursor CURSOR FOR
      SELECT A.workno, A.drumno, A.flow_seq, A.trxano, A.trxano_seq, A.print_seq AS seq FROM deleted A
      OPEN deleted_cursor
      FETCH NEXT FROM deleted_cursor INTO @workno, @drumno, @flow_seq, @trxano, @trxano_seq, @seq;
      WHILE @@FETCH_STATUS = 0
      BEGIN
        /* [生產單號]前置2碼<>"HC"才須同步舊模組 */
        IF LEFT(@trxano, 2) <> 'HC'
        BEGIN
          DELETE ['+@OLD_DBNAME +'].[dbo].[TBMUMLOT] WHERE workno = SUBSTRING(@workno, 2, LEN(@workno)) AND drumno = @drumno AND 
                                                           trxano = @trxano AND trxano_seq = @trxano_seq AND seq = @seq
        END 
        FETCH NEXT FROM deleted_cursor INTO @workno, @drumno, @flow_seq, @trxano, @trxano_seq, @seq;
    END
    CLOSE deleted_cursor;
    DEALLOCATE deleted_cursor;
  END

END TRY

BEGIN CATCH
  DECLARE @ErrMsg NVARCHAR(4000);
  DECLARE @ErrProcedure NVARCHAR(128);
  DECLARE @ErrMsgToThrow NVARCHAR(4000);
  SET @ErrMsg = ERROR_MESSAGE();
  SET @ErrProcedure = ERROR_PROCEDURE();
  SET @ErrMsgToThrow = '錯誤程序名稱:' + @ErrProcedure + ':' + @ErrMsg + 
                       '(Key:' + @workno + '-' + CONVERT(NVARCHAR(10), @drumno) + '-' + CONVERT(NVARCHAR(3), @flow_seq) + '-' + @trxano + '-' + @trxano_seq + '-' + CONVERT(NVARCHAR(5), @seq) + ')';

  RAISERROR(@ErrMsgToThrow, 16, 1);
END CATCH;

SET NOCOUNT OFF;
