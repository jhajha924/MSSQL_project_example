/* TBMUMLOT 流程卡生產記錄作業生產明細檔更新回舊模組【MU310、MU320】相關"生產序號"欄位 */
/* 
【修改歷程】 
  1. 2023/12/18 jha [20231114002]新增此Trigger
  2. 2024/01/15 jha [20231221003]調整Trigger名稱(原Trigger_DGF_TBMUMLOT_U_mlot_seq) + 新增同步異動舊模組欄位【MU320】[收料註記]
  3. 2024/11/25 huei [20241016002]#12 MU330拆單收料，要找母卡的生產單號回MU310更新生產序號
*/
CREATE TRIGGER [Trigger_DGF_TBMUMLOT_U_Old_TBMUOUTB_TBMUOUTF_TO_DG] ON [dbo].[TBMUMLOT]
AFTER INSERT, UPDATE 
AS
SET NOCOUNT ON;
DECLARE @workno NVARCHAR(34);
DECLARE @drumno INT;
DECLARE @flow_seq INT;
DECLARE @trxano NVARCHAR(10);
DECLARE @trxano_seq NVARCHAR(3);
DECLARE @seq INT;
DECLARE @drumno_M_trxano NVARCHAR(10);
DECLARE @OUTB_outano NVARCHAR(10);
BEGIN TRY
  /* 工令號要移除新模組的前置碼S */
  IF EXISTS (SELECT 1 FROM inserted) 
  BEGIN
   DECLARE inserted_cursor CURSOR FOR
    /* 在【Trigger_DGF_TBMUMLOT_TO_DG】，更新新模組【MU410】[列印序號]欄位並不會再次觸發本身Trigger，故inserted資料中的@seq還是原本的0 */
    SELECT A.workno, A.drumno, A.flow_seq, A.trxano, A.trxano_seq, A.print_seq AS seq FROM inserted A;
    OPEN inserted_cursor;
    FETCH NEXT FROM inserted_cursor INTO @workno, @drumno, @flow_seq, @trxano, @trxano_seq, @seq;
    WHILE @@FETCH_STATUS = 0
    BEGIN
      /* 2024/11/25 huei [20241016002]#12 若是拆桶，要找母卡的生產單號 */
      SELECT @drumno_M_trxano = (CASE WHEN ISNULL(B.[state], '') = '' AND ISNULL(A.drumno_source, '') = '拆桶' THEN C.trxano ELSE '' END)
      FROM TBMUMLOT A  
      LEFT JOIN TBMUWKDR B ON B.drumno = A.drumno AND B.old = ''
      LEFT JOIN TBMUMLOT C ON C.workno = @workno AND C.drumno = B.drumno_M AND C.flow_seq = @flow_seq
      WHERE A.workno = @workno AND A.drumno = @drumno AND A.trxano = @trxano AND A.trxano_seq = @trxano_seq AND A.flow_seq = @flow_seq

      SET @OUTB_outano = CASE WHEN ISNULL(@drumno_M_trxano, '') <> '' THEN @drumno_M_trxano ELSE @trxano END;

      /* 依【MU410】[生產單號+流程卡號] */
	  /* 將【MU410】[列印序號]更新至舊模組【MU310】相同[工令編號+流程卡號]的[生產序號] */
      UPDATE ['+@OLD_DBNAME +'].[dbo].[TBMUOUTB] SET mlot_seq = B2.print_seq
      FROM ['+@OLD_DBNAME +'].[dbo].[TBMUOUTB] B1
      JOIN TBMUMLOT B2 ON B2.workno = @workno AND B2.drumno = @drumno AND B2.trxano = @trxano AND B2.trxano_seq = @trxano_seq AND
		                  B2.flow_seq = @flow_seq
	  WHERE B1.outano = @OUTB_outano AND B1.drumno = @drumno;

      /* 依【MU410】[生產單號+生產單序] */
	  /* 將【MU410】[列印序號]更新至舊模組【MU320】相同[生產單號+生產單序]的[生產序號] */
      UPDATE ['+@OLD_DBNAME +'].[dbo].[TBMUOUTF] SET mlot_seq = B2.print_seq,
                                                     rece_ok = CASE WHEN ISNULL(B3.[state], '') = '' AND ISNULL(B2.drumno_source, '') = '' THEN N'O'
                                                                    WHEN ISNULL(B3.[state], '') = 'D' OR ISNULL(B3.[state], '') = 'E' OR ISNULL(B3.[state], '') = 'X' THEN 'Y'
                                                                    WHEN ISNULL(B3.[state], '') = '' AND ISNULL(B2.drumno_source, '') = '拆桶' THEN 'A'
                                                                    WHEN ISNULL(B3.[state], '') = '' AND ISNULL(B2.drumno_source, '') = '增補' THEN 'M'
                                                                    ELSE '' END
      FROM ['+@OLD_DBNAME +'].[dbo].[TBMUOUTF] B1
      JOIN TBMUMLOT B2 ON B2.workno = @workno AND B2.drumno = @drumno AND B2.trxano = @trxano AND B2.trxano_seq = @trxano_seq AND
		                  B2.flow_seq = @flow_seq
	  LEFT JOIN TBMUWKDR B3 ON B3.drumno = B2.drumno AND B3.old = ''
      WHERE B1.outeno = @trxano AND B1.outeno_seq = @trxano_seq;

      FETCH NEXT FROM inserted_cursor INTO @workno, @drumno, @flow_seq, @trxano, @trxano_seq, @seq;
      
    END
    CLOSE inserted_cursor;
    DEALLOCATE inserted_cursor;
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
