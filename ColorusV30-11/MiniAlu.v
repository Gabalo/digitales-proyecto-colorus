
`timescale 1ns / 1ps
`include "Defintions.v"


module MiniAlu
(
 input wire Clock,
 input wire Reset,
 output wire [7:0] oLed,
 output wire  VGA_HSYNC ,
 output wire  VGA_VSYNC ,
 output wire  VGA_RED ,
 output wire  VGA_GREEN ,
 output wire  VGA_BLUE
);

wire [15:0]  wIP,wIP_temp,wIP_return;
reg         rWriteEnable,rBranchTaken,rReturn,rCall,rVideoMemWrite;
wire [27:0] wInstruction;
wire [3:0]  wOperation;
reg  [15:0]   rResult;
wire [7:0]  wSourceAddr0,wSourceAddr1,wDestination, wDestinationPrev;
wire [15:0] wSourceData0,wSourceData1,c,wSourceData1_RAM,wSourceData0_RAM,wResultPrev,wIPInitialValue,wDestinationJump,wImmediateValue;
wire wHazard0, wHazard1, wWriteEnablePrev, wIsImmediate,wPushAddr;
wire [9:0] wColumnCount;
wire [9:0] wRowCount;
wire [2:0] wColorToMemory,iPixel;
wire [2:0] wColorActual;
 
//wire wVGA_RED,wVGA_GREEN,wVGA_BLUE;

ROM InstructionRom
(
	.iAddress(     wIP          ),
	.oInstruction( wInstruction )
);

RAM_DUAL_READ_PORT DataRam
(
	.Clock(         Clock        ),
	.iWriteEnable(  rWriteEnable ),
	.iReadAddress0( wInstruction[7:0] ),
	.iReadAddress1( wInstruction[15:8] ),
	.iWriteAddress( wDestination ),
	.iDataIn(       rResult      ),
	.oDataOut0(     wSourceData0_RAM ),
	.oDataOut1(     wSourceData1_RAM )
);

assign wDestinationJump = (rReturn) ? wIP_return : wDestination;
assign wIPInitialValue = (Reset) ? 8'b0 : wDestinationJump;
UPCOUNTER_POSEDGE IP
(
.Clock(   Clock                ),
.Reset(   Reset | rBranchTaken ),
.Initial( wIPInitialValue + 16'd1 ),
.Enable(  1'b1                 ),
.Q(       wIP_temp             )
);
assign wIP = (rBranchTaken) ? wIPInitialValue : wIP_temp;

FFD_POSEDGE_SYNCRONOUS_RESET # ( 4 ) FFD1
(
	.Clock(Clock),
	.Reset(Reset),
	.Enable(1'b1),
	.D(wInstruction[27:24]),
	.Q(wOperation)
);

FFD_POSEDGE_SYNCRONOUS_RESET # ( 8 ) FFD2
(
	.Clock(Clock),
	.Reset(Reset),
	.Enable(1'b1),
	.D(wInstruction[7:0]),
	.Q(wSourceAddr0)
);

FFD_POSEDGE_SYNCRONOUS_RESET # ( 8 ) FFD3
(
	.Clock(Clock),
	.Reset(Reset),
	.Enable(1'b1),
	.D(wInstruction[15:8]),
	.Q(wSourceAddr1)
);

FFD_POSEDGE_SYNCRONOUS_RESET # ( 8 ) FFD4
(
	.Clock(Clock),
	.Reset(Reset),
	.Enable(1'b1),
	.D(wInstruction[23:16]),
	.Q(wDestination)
);


reg rFFLedEN;
FFD_POSEDGE_SYNCRONOUS_RESET # ( 8 ) FF_LEDS
(
	.Clock(Clock),
	.Reset(Reset),
	.Enable( rFFLedEN ),
	.D( wSourceData1[7:0] ),
	.Q( oLed    )
);
reg rColorEnable ;
reg rSetColor ; 
FFD_POSEDGE_SYNCRONOUS_RESET # ( 3 ) FF_COLOR
(
	.Clock(Clock),
	.Reset(Reset),
	.Enable( rColorEnable ),
	.D( wSourceData1[2:0] ),
	.Q(   wColorActual  )
);

assign wImmediateValue = {wSourceAddr1,wSourceAddr0};

/////////////////////////////////
// Data Hazards en el pipeline //

FFD_POSEDGE_SYNCRONOUS_RESET # ( 8 ) FFD41
(
	.Clock(Clock),
	.Reset(Reset),
	.Enable(1'b1),
	.D(wDestination),
	.Q(wDestinationPrev)
);

FFD_POSEDGE_SYNCRONOUS_RESET # ( 16 ) FFDRES
(
	.Clock(Clock),
	.Reset(Reset),
	.Enable(rWriteEnable),
	.D(rResult),
	.Q(wResultPrev)
);


FFD_POSEDGE_SYNCRONOUS_RESET # ( 1 ) FFDWRITE
(
	.Clock(Clock),
	.Reset(Reset),
	.Enable(1'b1),
	.D( {rWriteEnable} ),
	.Q( {wWriteEnablePrev} )
);

assign wIsImmediate = wOperation[3] && wOperation[2];

assign wHazard0 = ((wDestinationPrev == wSourceAddr0) && wWriteEnablePrev && ~wIsImmediate ) ? 1'b1 : 1'b0;
assign wHazard1 = ((wDestinationPrev == wSourceAddr1) && wWriteEnablePrev && ~wIsImmediate ) ? 1'b1 : 1'b0;

assign wSourceData0 = (wHazard0) ? wResultPrev : wSourceData0_RAM;
assign wSourceData1 = (wHazard1) ? wResultPrev : wSourceData1_RAM;




//                             //
/////////////////////////////////

/////////////////////////////////
//           CALL RET          //

// assign wPushAddr = (wInstruction[27:24] == `CALL);
//assign wPushAddr = (wOperation == `CALL);

FFD_POSEDGE_SYNCRONOUS_RESET # ( 16 ) FF_RET
(
	.Clock(~Clock),
	.Reset(Reset),
	.Enable( rCall ),
	.D( wIP_temp ),
	.Q( wIP_return )
);

//                             //
/////////////////////////////////
 assign  wColorToMemory = wSourceData1 [2:0] ;
 //////////////////////////////
// VGA Controler and Memory //
wire [2:0] ColorBG ;
 
VGA_Controller vga (
	.Clock(Clock),
	.Enable(1'b1),
	.Reset(Reset),
	.iPixel(iPixel),
	.oHorizontalSync(VGA_HSYNC),
	.oVerticalSync(VGA_VSYNC),
	.oRed(ColorBG[2]),
	.oGreen(ColorBG[1]),
	.oBlue(ColorBG[0]),
	.oColumnCount(wColumnCount),
	.oRowCount(wRowCount)
);
// Instanciar memoria aqui

/*
FFD_POSEDGE_SYNCRONOUS_RESET # ( 3 ) FF_VGA_TIMING
(
	.Clock(Clock),
	.Reset(Reset),
	.Enable(1'b1),
	.D( {wVGA_RED,wVGA_GREEN,wVGA_BLUE} ),
	.Q( {VGA_RED,VGA_GREEN,VGA_BLUE} )
);
*/


RAM_SINGLE_READ_PORT # (3,10,1023) VideoMemory
(
.Clock( Clock ),
.iWriteEnable(rVideoMemWrite),
.iReadAddress( {wRowCount[8:4],wColumnCount[9:5]} ),
.iWriteAddress( wSourceData0[9:0] ),
.iDataIn( wColorToMemory  ),
.oDataOut( iPixel )
);

Sprite16x16 uut (
		.Clock(Clock), 
		.Reset(Reset), 
		.iColumnCount(wColumnCount), 
		.iRowCount(wRowCount), 
		.iEnable(1'b1), 
		.iColorBack(ColorBG), 
		.iChangePos(1'b1), 
		.iAbsolute(1'b0), 
		.iSetX(5'b00001), 
		.iSetY(5'b00001), 
		.iNewColor(wColorActual), 
		.iSetColor(rSetColor), 
		.oRGB({VGA_RED,VGA_GREEN,VGA_BLUE})
	);


always @ ( * )
begin
	case (wOperation)
	//-------------------------------------
	`NOP:
	begin
		rSetColor    <= 1'b0;
		rFFLedEN     <= 1'b0;
		rBranchTaken <= 1'b0;
		rWriteEnable <= 1'b0;
		rResult      <= 0;
		rReturn      <= 1'b0;
		rCall        <= 1'b0;
		rVideoMemWrite <= 1'b0;
		rColorEnable <= 1'b0;
	end
	//-------------------------------------
	`ADD:
	begin
		rSetColor    <= 1'b0;
		rFFLedEN     <= 1'b0;
		rBranchTaken <= 1'b0;
		rWriteEnable <= 1'b1;
		rResult      <= wSourceData1 + wSourceData0;
		rReturn      <= 1'b0;
		rCall        <= 1'b0;
		rVideoMemWrite <= 1'b0;
		rColorEnable <= 1'b0;
	end
	//-------------------------------------
	`SUB:
	begin
		rSetColor    <= 1'b0;
		rFFLedEN     <= 1'b0;
		rBranchTaken <= 1'b0;
		rWriteEnable <= 1'b1;
		rResult      <= wSourceData1 - wSourceData0;
		rReturn      <= 1'b0;
		rCall        <= 1'b0;
		rVideoMemWrite <= 1'b0;
		rColorEnable <= 1'b0;
	end
	//-------------------------------------
	`STO:
	begin
		rSetColor    <= 1'b0;
		rFFLedEN     <= 1'b0;
		rWriteEnable <= 1'b1;
		rBranchTaken <= 1'b0;
		rResult      <= wImmediateValue;
		rReturn      <= 1'b0;
		rCall        <= 1'b0;
		rVideoMemWrite <= 1'b0;
		rColorEnable <= 1'b0;
	end
	//-------------------------------------
	`BLE:
	begin
		rColorEnable <= 1'b0;
		rSetColor    <= 1'b0;
		rFFLedEN     <= 1'b0;
		rWriteEnable <= 1'b0;
		rResult      <= 0;
		if (wSourceData1 <= wSourceData0 )
			rBranchTaken <= 1'b1;
		else
			rBranchTaken <= 1'b0;
		rReturn      <= 1'b0;
		rCall        <= 1'b0;
		rVideoMemWrite <= 1'b0;
		

	end
	//-------------------------------------
	`JMP:
	begin
		rFFLedEN     <= 1'b0;
		rWriteEnable <= 1'b0;
		rResult      <= 0;
		rBranchTaken <= 1'b1;
		rReturn      <= 1'b0;
		rCall        <= 1'b0;
		rVideoMemWrite <= 1'b0;
		rColorEnable <= 1'b0;
		rSetColor    <= 1'b0;
	end
	//-------------------------------------
	`CALL:
	begin
		rFFLedEN     <= 1'b0;
		rWriteEnable <= 1'b0;
		rResult      <= 0;
		rBranchTaken <= 1'b1;
		rReturn      <= 1'b0;
		rCall        <= 1'b1;
		rVideoMemWrite <= 1'b0;
		rColorEnable <= 1'b0;
		rSetColor    <= 1'b0;
	end
	//-------------------------------------
	`RET:
	begin
		rFFLedEN     <= 1'b0;
		rWriteEnable <= 1'b0;
		rResult      <= 0;
		rBranchTaken <= 1'b1;
		rReturn      <= 1'b1;
		rCall        <= 1'b0;
		rVideoMemWrite <= 1'b0;
		rColorEnable <= 1'b0;
		rSetColor    <= 1'b0;
	end
	//-------------------------------------
	`LED:
	begin
		rFFLedEN     <= 1'b1;
		rWriteEnable <= 1'b0;
		rResult      <= 0;
		rBranchTaken <= 1'b0;
		rReturn      <= 1'b0;
		rCall        <= 1'b0;
		rVideoMemWrite <= 1'b0;
		rColorEnable <= 1'b0;
		rSetColor    <= 1'b0;
	end

	`WVM :
	begin
		rFFLedEN     <= 1'b0;
		rWriteEnable <= 1'b0;
		rResult      <= 0;
		rBranchTaken <= 1'b0;
		rReturn      <= 1'b0;
		rCall        <= 1'b0;
		rVideoMemWrite <= 1'b1;
		rColorEnable <= 1'b0;
		rSetColor    <= 1'b0;

	end
	
		`CHCOLOR :
	begin
		rFFLedEN     <= 1'b0;
		rColorEnable <= 1'b1;
		rSetColor    <= 1'b1;

	end


	//-------------------------------------
	default:
	begin
		rFFLedEN     <= 1'b1;
		rWriteEnable <= 1'b0;
		rResult      <= 0;
		rBranchTaken <= 1'b0;
		rReturn      <= 1'b0;
		rCall        <= 1'b0;
		rVideoMemWrite <= 1'b0;
		rColorEnable <= 1'b0;
	end
	//-------------------------------------
	endcase
end


endmodule
