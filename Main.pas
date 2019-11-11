unit Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ExtCtrls, System.ImageList, Vcl.ImgList, Vcl.ComCtrls,
  System.Generics.Defaults, System.Generics.Collections;

type
  Tresult_item = record
    pos: integer;
    code: integer;
  end;

  TForm2 = class(TForm)
    pnl_1: TPanel;
    btn_Run: TButton;
    mem: TMemo;
    ed_CodeWindowLen: TEdit;
    lbl_1: TLabel;
    lbl_2: TLabel;
    ed_FileName: TButtonedEdit;
    il1: TImageList;
    dlg_OpenFile: TOpenDialog;
    lbl_3: TLabel;
    ed_StartCode: TEdit;
    progr_bar: TProgressBar;
    tmr_1: TTimer;
    edt_Group: TEdit;
    lbl_4: TLabel;
    chk_Iverse: TCheckBox;
    procedure btn_RunClick(Sender: TObject);
    procedure ed_FileNameRightButtonClick(Sender: TObject);
    procedure tmr_1Timer(Sender: TObject);
  private
    CODE_LEN: integer;
    ARR_LEN: integer;
    CODE_MASK: integer;
    bits: array of byte;
    codes: array of long;
    probes: array of long;
    current_pos: long;
    res_arr: TArray<Tresult_item>;
    comparer_by_pos: IComparer<Tresult_item>;
    function Not_uniquie(code: long; var match_position: long): boolean;
  public
    { Public declarations }
  end;

var
  Form2: TForm2;

implementation

{$R *.dfm}

function TForm2.Not_uniquie(code: long; var match_position: long): boolean;
var
  i: long;
begin
  for i := 0 to current_pos - 1 do
  begin
    if codes[i] = code then
    begin
      match_position := i;
      result := True;
      exit;
    end;
  end;
  match_position := current_pos;
  result := False;
end;

procedure TForm2.tmr_1Timer(Sender: TObject);
begin
  progr_bar.Visible := False;
  tmr_1.Enabled := False;
end;

procedure TForm2.ed_FileNameRightButtonClick(Sender: TObject);
begin
  if dlg_OpenFile.Execute = True then
  begin
    ed_FileName.Text := dlg_OpenFile.FileName;
  end;
end;

procedure TForm2.btn_RunClick(Sender: TObject);
var
  start_code: integer;
  code: integer;
  max_pos: integer;
  p: integer;
  match_pos: long;
  i, j: long;
  str: string;
  strl: TStringList;
  bits_in_group_num: integer;
  bits_cnt: integer;
  bits_str: string;
  group_bits: integer;
  group_bits_mask: integer;
  group_bits_len: integer;
  inv_bit : integer;
begin
  CODE_LEN := StrToInt(ed_CodeWindowLen.Text);
  if CODE_LEN > 16 then
  begin
    ShowMessage('Too long window');
    Abort;
  end;
  if CODE_LEN < 3 then
  begin
    ShowMessage('Too short window');
    Abort;
  end;

  ARR_LEN := (1 shl CODE_LEN);
  CODE_MASK := ARR_LEN - 1;

  start_code := StrToInt(ed_StartCode.Text);
  bits_in_group_num := StrToInt(edt_Group.Text);
  group_bits_len := 1 shl bits_in_group_num;
  group_bits_mask := group_bits_len - 1;

  progr_bar.Min := 0;
  progr_bar.Max := ARR_LEN;
  progr_bar.Step := 1;
  progr_bar.Position := 0;
  progr_bar.Visible := True;

  if chk_Iverse.Checked then inv_bit:= 1 else  inv_bit:= 0;


  max_pos := 0;

  current_pos := 0;

  SetLength(bits, ARR_LEN);
  SetLength(codes, ARR_LEN + CODE_LEN);
  SetLength(probes, ARR_LEN);

  try
    screen.Cursor := crHourGlass;
    mem.Lines.Clear;

    bits[current_pos] := start_code and 1;
    while current_pos < ARR_LEN do
    begin
    // Добавляем бит в текущую позицию
    // Значение бита зависит от того сколько раз он был использован
      if probes[current_pos] < 2 then
      begin
        if probes[current_pos] = 0 then
          bits[current_pos] := 1 xor inv_bit
        else
          bits[current_pos] := 0 xor inv_bit;
        Inc(probes[current_pos]);
      end
      else
      begin
        mem.Lines.Add('All variants is used. End of search.');
        Abort;
      end;

      if current_pos > 0 then
      begin
      // Вычисляем следующий код
        code := codes[current_pos - 1] shl 1;
        code := (code + bits[current_pos]) and CODE_MASK;
        codes[current_pos] := code;


        // Проверяем на отсутствие повторений
        if Not_uniquie(code, match_pos) then
        begin
        // Обнаружено повторений, возвращаемся назад до ближайшего бита который можно изменить
          while current_pos > 0 do
          begin
            p := probes[current_pos];
            if p < 2 then
              break;
            probes[current_pos] := 0;
            Dec(current_pos);
          end;
          if current_pos = 0 then
          begin
            mem.Lines.Add('All variants is used. End of search.');
            Abort;
          end;
          continue;
        end;

        Inc(current_pos);
        if current_pos > max_pos then
        begin
          max_pos := current_pos;
          progr_bar.Position := max_pos;
          application.ProcessMessages;
        end;
      end
      else
      begin
        codes[current_pos] := start_code;
        Inc(current_pos);
      end;

    end;

    progr_bar.Position := progr_bar.Max;
    application.ProcessMessages;

    mem.Lines.Add('');
    mem.Lines.Add('Result');
    mem.Lines.Add('');

    SetLength(res_arr, ARR_LEN);
    bits_cnt := 0;
    group_bits := 0;
    mem.Lines.BeginUpdate;
    strl := TStringList.Create;
    for i := 0 to ARR_LEN - 1 do
    begin
      str := '';
      for j := 1 to CODE_LEN do
      begin
        if (codes[i] and (ARR_LEN shr j)) <> 0 then
          str := str + '1'
        else
          str := str + '0';
      end;

      res_arr[i].pos := i;
      res_arr[i].code := codes[i];

      if bits_cnt = 0 then
      begin
        bits_str := '';
        group_bits := 0;
        for j := 0 to bits_in_group_num - 1 do
        begin
          if (i + j) = 0 then
          begin
            group_bits := ((group_bits shl 1) + (codes[0] and 1)) and group_bits_mask;
            if (codes[0] and 1) <> 0 then
              bits_str := bits_str + '1'
            else
              bits_str := bits_str + '0';
          end
          else
          begin
            group_bits := ((group_bits shl 1) + bits[i + j]) and group_bits_mask;
            if bits[i + j] <> 0 then
              bits_str := bits_str + '1'
            else
              bits_str := bits_str + '0';
          end;

        end;
      end;
      Inc(bits_cnt);
      bits_cnt := bits_cnt mod bits_in_group_num;

      if bits_str <> '' then
      begin
        strl.Add(format('Pos: %05.5d  Bit: %d  Code: %s  0x%04.4X  %.5d  Grouped: %s  0x%04.4X  %d', [i, bits[i], str, codes[i], codes[i], bits_str,group_bits, group_bits]));
        bits_str := '';
      end
      else
      begin
        strl.Add(format('Pos: %05.5d  Bit: %d  Code: %s  0x%04.4X  %.5d', [i, bits[i], str, codes[i], codes[i]]));
      end;
    end;
    mem.Lines.Text := strl.Text;
    mem.Lines.EndUpdate;

    if ed_FileName.Text <> '' then
    begin
      strl.Clear;
      strl.Add('#include <stdint.h>');
      strl.Add('');
      strl.Add(format('uint32_t ss_pos_to_code[%d] = ', [ARR_LEN]));
      strl.Add('{');
      for i := 0 to ARR_LEN - 1 do
      begin
        strl.Add(format(' {%05.5d, 0x%04.4X }, ', [res_arr[i].pos, res_arr[i].code]));
      end;
      strl.Add('};');

      comparer_by_pos := TDelegatedComparer<Tresult_item>.Create(
        function(const Left, Right: Tresult_item): Integer
        begin
          Result := Left.code - Right.code;
        end);
      TArray.Sort<Tresult_item>(res_arr, comparer_by_pos);

      strl.Add('');
      strl.Add(format('uint32_t ss_code_to_pos[%d] = ', [ARR_LEN]));
      strl.Add('{');
      for i := 0 to ARR_LEN - 1 do
      begin
        strl.Add(format(' {%05.5d, 0x%04.4X }, ', [res_arr[i].pos, res_arr[i].code]));
      end;
      strl.Add('};');

      strl.SaveToFile(ed_FileName.Text);

    end;

  finally
    SetLength(bits, 0);
    SetLength(codes, 0);
    SetLength(probes, 0);
    screen.Cursor := crDefault;
    tmr_1.Enabled := True;
  end;
end;

end.

