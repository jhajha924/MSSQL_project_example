/* TBMUMLOT 流程卡生產記錄作業新增資料時先更新[列印序號]欄位專用Trigger */
/* 
【修改歷程】：
   1. 2024/01/12 jha [20231220009]新增此Trigger
   2. 2024/04/08 jha [20240325001]調整Trigger判斷
*/
CREATE TRIGGER [dbo].[Trigger_DGF_TBMUMLOT_U_print_seq] ON [dbo].[TBMUMLOT]
INSTEAD OF INSERT
AS
  SET NOCOUNT ON;
  DECLARE @workno NVARCHAR(34);
  DECLARE @drumno INT;
  DECLARE @flow_seq INT;
  DECLARE @trxano NVARCHAR(10);
  DECLARE @trxano_seq NVARCHAR(3);
  DECLARE @print_seq INT;
  DECLARE inserted_cursor CURSOR FOR
    SELECT workno, drumno, flow_seq, trxano, trxano_seq, ISNULL(print_seq, 0) AS print_seq FROM inserted;
    OPEN inserted_cursor;
    FETCH NEXT FROM inserted_cursor INTO @workno, @drumno, @flow_seq, @trxano, @trxano_seq, @print_seq;
    WHILE @@FETCH_STATUS = 0
    BEGIN

      INSERT INTO TBMUMLOT(
        workno, drumno, flow_seq, flow, flow_desc, flow_seq_n, flow_n, flow_desc_n, 
        beg_date, end_date, area, custno_o, short_n_o, machno_o, mach_type_o, custno,
        short_n, machno, mach_type, sect, userid, userna, trxano_kind, trxano, trxano_seq, 
        flow_wet, drum_a, drum_b, drum_c, wet, qty, pay_trxano_kind, pay_trxano, pay_trxano_seq,
        pay_flow_wet, pay_drum_a, pay_drum_b, pay_drum_c, pay_wet, pay_qty, workno_o,
        trxcno, trxcno_seq, lotno, matr, matr_desc, spec_code, spec, qc_code, qc_chk,
        work_desc, print_seq, drumno_source, createman, createdate, modifyman, modifydate
      )
      SELECT A.workno, A.drumno, A.flow_seq, A.flow, A.flow_desc, A.flow_seq_n, A.flow_n, A.flow_desc_n, 
             A.beg_date, A.end_date, A.area, A.custno_o, A.short_n_o, A.machno_o, A.mach_type_o, A.custno,
             A.short_n, A.machno, A.mach_type, A.sect, A.userid, A.userna, A.trxano_kind, A.trxano, A.trxano_seq, 
             A.flow_wet, A.drum_a, A.drum_b, A.drum_c, A.wet, A.qty, A.pay_trxano_kind, A.pay_trxano, A.pay_trxano_seq,
             A.pay_flow_wet, A.pay_drum_a, A.pay_drum_b, A.pay_drum_c, A.pay_wet, A.pay_qty, A.workno_o,
             A.trxcno, A.trxcno_seq, A.lotno, A.matr, A.matr_desc, A.spec_code, A.spec, A.qc_code, A.qc_chk, A.work_desc, 
             CASE WHEN @print_seq = 0 THEN ISNULL(B.print_seq, 0) + 1 
                  ELSE @print_seq END,
             A.drumno_source, A.createman, A.createdate, A.modifyman, A.modifydate
      FROM inserted A
      LEFT JOIN (SELECT workno, drumno, MAX(ISNULL(print_seq, 0)) AS print_seq FROM TBMUMLOT 
	             GROUP BY workno, drumno) B ON B.workno = A.workno AND B.drumno = A.drumno
	  WHERE A.workno = @workno AND A.drumno = @drumno AND A.flow_seq = @flow_seq AND A.trxano = @trxano AND A.trxano_seq = @trxano_seq;

      FETCH NEXT FROM inserted_cursor INTO @workno, @drumno, @flow_seq, @trxano, @trxano_seq, @print_seq;
 END
 CLOSE inserted_cursor;
 DEALLOCATE inserted_cursor;

SET NOCOUNT OFF;
