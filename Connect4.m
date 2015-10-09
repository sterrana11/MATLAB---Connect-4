function varargout = connect4(varargin)
% Play Connect 4!
% 
% If you want to edit the board colors, you may input your own.
% 
%       Acceptable Input Properties:
%       'BoardColor'
%       'BoardAccentColor'
%       'Player1Color'
%       'Player2Color'
%       'Bounce'
%       'AnimateDrop'
% 
%       Acceptable Inputs are the standard color strings
%           white    -- 'w'
%           black    -- 'k'
%           yellow   -- 'y'
%           magenta  -- 'm'
%           cyan     -- 'c'
%           red      -- 'r'
%           green    -- 'g'
%           blue     -- 'b'
% 
%       or RGB color vectors. 
% 
% You may also turn off:
%   The physical dynamics by specifying 'Bounce','off'
%   The Board Clearing Animation by specifying 'AnimateDrop','off'
% 
% 
% Created By:  Steven Terrana
%       Date:  March 19th, 2015

%---------------- BEGIN INPUT ERROR PROOFING ----------------------------%

% even number of inputs, they come in pairs.
if rem(nargin,2)
    error('There must be an even number of inputs.')
end

% cell of acceptable properties
props = {'BoardColor',...
         'BoardAccentColor',...
         'Player1Color',...
         'Player2Color',...
         'Bounce',...
         'AnimateDrop'};

% make sure property inputs are acceptable
%   Note: case insensitive
for i = 1:2:length(varargin)
    if ~sum(strcmpi(varargin{i},props))
        error('''%s'' is not an accessable property.',varargin{i})
    end
end

% Cell of acceptable color inputs
color_options = {'r','b','m','c','w','k','g','y'};

% check the inputs 
for i = 2:2:length(varargin)
    % the input is for a color property
    if sum(strcmpi(varargin(i-1),props(1:4)))
        if ischar(varargin{i}) % the user is trying to do a color string
            if ~sum(strcmp(color_options,varargin{i}))
                error('''%s'' is not an acceptable color input.',varargin{i})
            end 
        else % the user is trying to do a RGB vector
            if ~isequal(size(varargin{i}),[1 3]) || sum( varargin{i} < 0 )  || sum( varargin{i} > 1 )
                error('RGB Vectors are [1X3] vectors containing values between [0,1]')
            end
        end
    else % the input is for bounce or animatedrop
        if ~sum(strcmp({'on','off'},varargin{i}))
            error('''%s'' is not an option.  ''%s'' must either be ''on'' or ''off''',varargin{i},varargin{i-1})
        end
    end
end

% -- Set the properties if specified, otherwise set defaults -- %
if sum(strcmpi('BoardColor',varargin))
    callback.colors.BoardColor = varargin{find(strcmpi('BoardColor',varargin)==1)+1};
else
    callback.colors.BoardColor = [0  0.5  0.8];
end

if sum(strcmpi('BoardAccentColor',varargin))
    callback.colors.BoardAccentColor = varargin{find(strcmpi('BoardAccentColor',varargin)==1)+1};
else
    callback.colors.BoardAccentColor = 'k';
end

if sum(strcmpi('Player1Color',varargin))
    callback.colors.Player1Color = varargin{find(strcmpi('Player1Color',varargin)==1)+1};
else
    callback.colors.Player1Color = 'r';
end

if sum(strcmpi('Player2Color',varargin))
    callback.colors.Player2Color = varargin{find(strcmpi('Player2Color',varargin)==1)+1};
else
    callback.colors.Player2Color = 'y';
end

if sum(strcmpi('Bounce',varargin))
    callback.bounce = varargin{find(strcmpi('bounce',varargin)==1)+1};
else
    callback.bounce = 'on'; 
end

if sum(strcmpi('AnimateDrop',varargin))
    callback.AnimateDrop = varargin{find(strcmpi('AnimateDrop',varargin)==1)+1};
else
    callback.AnimateDrop = 'on'; 
end
%-------------------------------------------------------------------------%

% Define a custom "invisible" pointer
%   "callback" is a structure containing the variables that must be
%   accessible in the various callbacks.  
callback.pointer_array = nan(16);

% define the figure window for the game
%   - invisible, for now
%   - default invisible pointer
%   - Not Resizable
%   - Normalize the units for programming on multiple screen sizes
%   - Get rid of the menubar
%   - Set the callbacks and only do one thing at a time. 
fig = figure(...
            'Pointer','custom',...
            'Visible','off',...
            'PointerShapeCData',callback.pointer_array,...
            'Resize','off',...
            'MenuBar','none',...
            'Units','normalized',...
            'Name', 'Connect 4!',...
            'NumberTitle','off');
set(fig,    'WindowButtonMotionFcn',{@mousemoving,fig},...
            'WindowButtonDownFcn',{@click,fig},...
            'Interruptible','off',...
            'BusyAction','cancel');

fig.Position(3:4) = [910 / 1600, 715/900]; % define size of window
movegui('center')                          % center the figure window on the screen

callback.hAxes = gca; % grab the handle to the figure window axes
set(callback.hAxes,...
                  'XLim',[ 0 9 ],...   set x axis limits
                  'YLim',[ 0 10],...   set y axis limits
                  'XTick',[],...       no x tick marks
                  'YTick',[],...       no y tick marks
                  'Box','on')        % show axes border
axis('square')                       % for aesthetics 

% Define the two buttons in the game.
%   1. a reset button to start the game over
%   2. a "play again" button for when the game's over.
callback.button = uicontrol(...
                  'Style','PushButton',...
                  'Units','normalized',...
                  'Position',[0.37 0.0280 0.3 0.05],...
                  'String','Reset',...
                  'Visible','off',...
                  'Callback',{@button_push,fig});
              
callback.play_again = uicontrol(...
                  'Style','Pushbutton',...
                  'String','Play Again',...
                  'Units','normalized',...
                  'Position',[0.417 0.8 0.2 0.05],...
                  'Visible','off',...
                  'Callback',{@play_again,fig});

% flag for making the reset
% button visible after a turn has been made
callback.reset_flag = 0;

% Define the size of the marker by
% how much of the slot you would like
% it to fill and back-calculate the
% corresponding radius required.
percent_of_slot = 0.50;
callback.radius = sqrt(percent_of_slot / pi);

% create the board:
%   in order for the piece to "fall" through the board
%   it was necessary to create the board using many patches 
%   and then assign the marker as the "first" child. 
border = 0.6; 

% define the x and y vectors for the patch components of the board.
%   each circular slot is composed of two patches that represent the
%   top half of the slot and the bottom half of the slot.
bx = linspace(-callback.radius,callback.radius);
by = sqrt(callback.radius^2 - (bx).^2);

board_piece_x = [bx,fliplr(bx)];          % x data for patches
top_y = [border * ones(1,100),by];        % y data for top patch
bottom_y = [-border * ones(1,100),- by];  % y data for bottom patch

% construct the board 
for j = 1.5:6.5
    for i = 1.5:7.5
        patch(board_piece_x +  i, top_y    + j,callback.colors.BoardColor,'EdgeAlpha',0);
        patch(board_piece_x +  i, bottom_y + j,callback.colors.BoardColor,'EdgeAlpha',0);
    end
end

% Fill in the vertical gaps in the board; 
for i = -1:6
    patch([ i + 1.8989 i + 2.1011 i + 2.1011 i + 1.8989],[0.9 0.9 7.1 7.1],callback.colors.BoardColor,'EdgeAlpha',0)
end

% Boarder the board (--> |_| <--)with a black line 
patch([0.8989 0.8989],[0.9 7.1],callback.colors.BoardAccentColor,'EdgeColor',callback.colors.BoardAccentColor,'LineWidth',2);
patch([0.8989 8.1011],[0.9 0.9],callback.colors.BoardAccentColor,'EdgeColor',callback.colors.BoardAccentColor,'LineWidth',2);
patch([8.1011 8.1011],[0.9 7.1],callback.colors.BoardAccentColor,'EdgeColor',callback.colors.BoardAccentColor,'LineWidth',2); 

% Define the interval from 0 to 2*pi for circle construction
callback.t = linspace(0,2*pi);

% Add transparent circular patches where the slots are
% to give them a border.
for i = 1.5:6.5
    for j = 1.5:7.5
        patch( j + callback.radius*cos(callback.t), i +callback.radius*sin(callback.t),callback.colors.BoardAccentColor,'EdgeColor',callback.colors.BoardAccentColor,'FaceAlpha',0,'LineWidth',1)
    end
end

% get the location of the mouse in the units of the axes
coords = get_coords(callback.hAxes);

% find the axis bounds
xl = xlim;
yl = ylim;

% this if-statement structure:
%   - keeps the circle inside the figure but above the game board
%   - changes what type of pointer is displayed
%       - invisible if moving the circle
%       - a hand if otherwise
set(fig,'Pointer','custom','PointerShapeCData',callback.pointer_array)
if coords(1) < (xl(1)+callback.radius)
    set(fig,'Pointer','hand')
    coords(1) = xl(1) + callback.radius;
end
if coords(1) > (xl(2) - callback.radius);
    set(fig,'Pointer','hand')
    coords(1) = xl(2) - callback.radius;
end
if coords(2) < 7.5
    set(fig,'Pointer','hand')
    coords(2) = 7.5;
end
if coords(2) > (yl(2) - callback.radius);
    set(fig,'Pointer','hand')
    coords(2) = yl(2) - callback.radius;
end

% construct a circle around the mouse
cx = coords(1) + callback.radius * cos(callback.t);
cy = coords(2) + callback.radius * sin(callback.t);

% create the patch 
callback.current_marker = patch(cx,cy,callback.colors.Player1Color,'EdgeColor','k','LineWidth',1.5);

% make it appear "behind" the board patches.
uistack(callback.current_marker,'bottom')

% Prep the necessary game variables
callback.turn = 1;                  %  players turn
callback.column_count = ones(1,7);  %  number of chips in each column
callback.player1 = zeros(6,7);      %  array with player one's chips
callback.player2 = zeros(6,7);      %  array with player two's chips
callback.marker_idx = 1;            %  index for storing marker handles

% set callback as the figures application data for 
% retrieval in the callbacks
guidata(fig,callback);

% let the user see the board
set(fig,'Visible','on')

% if the user want's the handle, give it to them. 
if nargout == 1
    varargout = {fig};
end


 

end

function mousemoving(~,~,fig)

% grab the data
callback = guidata(fig);

% get the mouse location in units of the axes
coords = get_coords(callback.hAxes);

% find the axis bounds
xl = xlim;
yl = ylim;

% this if-statement structure:
%   - keeps the circle inside the figure but above the game board
%   - changes what type of pointer is displayed
%       - invisible if moving the circle
%       - a hand if otherwise
set(fig,'Pointer','custom','PointerShapeCData',callback.pointer_array)
if coords(1) < (xl(1)+callback.radius)
    set(fig,'Pointer','hand')
    coords(1) = xl(1) + callback.radius;
end
if coords(1) > (xl(2) - callback.radius);
    set(fig,'Pointer','hand')
    coords(1) = xl(2) - callback.radius;
end
if coords(2) < 7.5
    set(fig,'Pointer','hand')
    coords(2) = 7.5;
end
if coords(2) > (yl(2) - callback.radius);
    set(fig,'Pointer','hand')
    coords(2) = yl(2) - callback.radius;
end

% move the location of the marker
set(callback.current_marker,'XData',coords(1) + callback.radius * cos(callback.t),'YData',coords(2) + callback.radius * sin(callback.t))

% update the data 
guidata(fig,callback)


end

function click(~,~,fig)

% grab the data
callback = guidata(fig);

% go determines if the click activates anything
go = 0;

% grab the mouse location in units of the Axes
coords = get_coords(callback.hAxes);

% to activate, pointer must be over the board (ie. 7.5)
if coords(2) >= 7.5
    
    % define how close to the center of the column one must click to
    % activate an event and then check if the mouse is above a column
    % within the allowable window.
    %
    % This loop also determines which column the mouse is over and makes
    % sure that the column isn't already full.
    allowance = 0.3;
    for i = 1.5:7.5  
        if coords(1)>= i - allowance && coords(1) <= i + allowance
            col = i - 0.5;
            if callback.column_count(col) < 7; % otherwise column full
                go = 1;
            end
        end
    end
        
    if go
        
        if ~callback.reset_flag 
            callback.reset_flag = 1;
            set(callback.button,'Visible','on')
        end
        
        % add the current marker to the markers matrix and increase the
        % index.
        callback.markers(callback.marker_idx) = callback.current_marker;
        callback.marker_idx = callback.marker_idx + 1;
        guidata(fig,callback);
        
        % temp_y_start is where the mouse is vertically.
        temp_y_start = get(callback.current_marker,'YData');
        % Where the marker will drop from, to 1 decimal
        y_start = round(temp_y_start(1),1);
                
        % drop the marker from its starting position and funnel it into the
        % column
        
        if strcmpi(callback.bounce,'off')
            for i = y_start:-0.1:callback.column_count(col)+0.5
                if i <= 7+round(callback.radius,1)
                    set(callback.current_marker,'XData',(col+0.5) + callback.radius*cos(callback.t));
                end
                set(callback.current_marker,'YData', i + callback.radius * sin(callback.t));
                pause(0.01)
            end
        else
            bounce(y_start,callback.column_count(col), callback.current_marker, callback.radius,col)
        end
        
        
                
        % update the player marker matrix        
        % if the last move resulted in a victory
        %   - display a message
        %   - display the play again button
        %   - remove the reset button
        %   - reset the game if necessary
        if callback.turn == 1
            callback.player1(7-callback.column_count(col),col) = 1;
            result = CheckForWinner(callback.player1,7-callback.column_count(col),col);
            if result
                callback.messagehandle = CreateMessage(fig,'Player 1 Wins!!',callback.colors.Player1Color);
                guidata(fig,callback)
                uiwait
            end
            callback.turn = 2;
            color = callback.colors.Player2Color;
        else
            callback.player2(7-callback.column_count(col),col) = 1;
            result = CheckForWinner(callback.player2,7-callback.column_count(col),col);
            if result == 1
                callback.messagehandle = CreateMessage(fig,'Player 2 Wins!!',callback.colors.Player2Color);
                guidata(fig,callback)
                uiwait
            end
            callback.turn = 1;
            color = callback.colors.Player1Color;
        end
        
        % assuming there was no victory and play continues then add the
        % previous marker to the column count
        callback.column_count(col) = callback.column_count(col) + 1;
        
        
        
        % if someone wins or if the board is full
        %   - clear the board
        %   - reset the game
        if result || isequal(callback.player1+callback.player2,ones(6,7))
            if isequal(callback.player1+callback.player2,ones(6,7))
                callback.messagehandle = CreateMessage(fig,'The Game is Drawn.',callback.colors.BoardColor);                
                guidata(fig,callback)
                uiwait
            end
            if strcmp(callback.AnimateDrop,'on')
                drop(fig)
            end
            delete(callback.markers)
            callback = rmfield(callback,'markers');
            callback.marker_idx = 1;
            callback.player1 = zeros(6,7);
            callback.player2 = zeros(6,7);
            callback.column_count = ones(1,7);
            callback.turn = 1;
        end
        
        % if the game's continuing, createa  new marker and place it where
        % the  mouse is 
        coords = get_coords(callback.hAxes);
        
        % find the axis bounds
        xl = xlim;
        yl = ylim;

        % this if-statement structure:
        %   - keeps the circle inside the figure but above the game board
        %   - changes what type of pointer is displayed
        %       - invisible if moving the circle
        %       - a hand if otherwise
        set(fig,'Pointer','custom','PointerShapeCData',callback.pointer_array)
        if coords(1) < (xl(1)+callback.radius)
            set(fig,'Pointer','hand')
            coords(1) = xl(1) + callback.radius;
        end
        if coords(1) > (xl(2) - callback.radius);
            set(fig,'Pointer','hand')
            coords(1) = xl(2) - callback.radius;
        end
        if coords(2) < 7.5
            set(fig,'Pointer','hand')
            coords(2) = 7.5;
        end
        if coords(2) > (yl(2) - callback.radius);
            set(fig,'Pointer','hand')
            coords(2) = yl(2) - callback.radius;
        end
        
        cx = coords(1) + callback.radius * cos(callback.t);
        cy = coords(2) + callback.radius * sin(callback.t);
        callback.current_marker = patch(cx,cy,color,'EdgeColor','k','LineWidth',1.5,'Visible','off');
        if result
            set(callback.current_marker,'FaceColor',callback.colors.Player1Color,'EdgeColor','k','LineWidth',1.5);
        end
        uistack(callback.current_marker,'bottom')       
    end
   
end

% update the data
guidata(fig,callback)
% to avoid a delay in marker visibility and being able to move the marker
% make the marker visible now.
set(callback.current_marker,'Visible','on')
end

function button_push(~,~,fig)
% reset the game 

% grab the data
callback = guidata(fig);

set(callback.button,'Visible','off')
callback.reset_flag = 0; 

if strcmp(callback.AnimateDrop,'on')
    set(callback.current_marker,'Visible','off')
    drop(fig)
    set(callback.current_marker,'Visible','on')
end

pause(0.1)

% delete all the markers and set game vars to new
delete(callback.markers)  % clear the board
callback = rmfield(callback,'markers');
callback.player1 = zeros(6,7); % reset the game data
callback.player2 = zeros(6,7);
callback.column_count = ones(1,7);
callback.turn = 1;
callback.marker_idx = 1; 

% change the marker to red if it was player 2's turn when you reset
set(callback.current_marker,'FaceColor',callback.colors.Player1Color,'EdgeColor','k','LineWidth',1.5);


% update the game data
guidata(fig,callback);



end

function play_again(~,~,fig)

% grab the data
callback = guidata(fig);

% delete the message
delete(callback.messagehandle)

% reassign the callbacks
set(fig,'WindowButtonMotionFcn',{@mousemoving,fig},'WindowButtonDownFcn',{@click,fig})

% hide play again button
set(callback.play_again,'Visible','off')

% show reset button
set(callback.button,'Visible','on')

% change the pointer back to invisible, continue the code. 
set(fig,'Pointer','custom','PointerShapeCData',nan*ones(16,16))
uiresume

end

function coords = get_coords(hAxes)
        %# Get the screen coordinates:
        coords = get_in_units(0,'PointerLocation','pixels');
        
        %# Get the figure position, axes position, and axes limits:
        hFigure = get(hAxes,'Parent');
        figurePos = get_in_units(hFigure,'Position','pixels');
        axesPos = get_in_units(hAxes,'Position','pixels');
        axesLimits = [get(hAxes,'XLim').' get(hAxes,'YLim').'];
        
        %# Compute an offset and scaling for coords:
        offset = figurePos(1:2)+axesPos(1:2);
        axesScale = diff(axesLimits)./axesPos(3:4);
        
        %# Apply the offsets and scaling:
        coords = (coords-offset).*axesScale+axesLimits(1,:);
        
        
        
        function [value]=get_in_units(hObject,propName,unitType)
            
            oldUnits = get(hObject,'Units');  %# Get the current units for hObject
            set(hObject,'Units',unitType);    %# Set the units to unitType
            value = get(hObject,propName);    %# Get the propName property of hObject
            set(hObject,'Units',oldUnits);    %# Restore the previous units
            
        end
end
    
function t = CreateMessage(fig,str,bgColor)
    callback = guidata(fig);
    t(1) = text(4.55,9.55,str,'HorizontalAlignment','center','FontSize',18);
    x = xlim; y = ylim;
    t(2) = line( [ (0.37 * diff(x))+x(1) - 0.9, 0.04 * diff(x) + 6.28] , ((0.87 * diff(y)) + y(1)+0.6)*ones(1,2)   ,'color','k','LineWidth',2);
    t(3) = line( ( (0.37 * diff(x))+x(1) - 0.94) * ones(1,2), [ (0.87 * diff(y)) + y(1)+0.6,(0.87 * diff(y)) + y(1)+1.11 ]   ,'color','k','LineWidth',2);
    t(4) = line(  (0.04 * diff(x) + 6.315) * ones(1,2), [ (0.87 * diff(y)) + y(1)+0.6,(0.87 * diff(y)) + y(1)+1.1 ]   ,'color','k','LineWidth',2);
    t(5) = line( [ (0.37 * diff(x))+x(1) - 0.93, 0.04 * diff(x) + 6.31] , ((0.87 * diff(y)) + y(1)+1.14)*ones(1,2)   ,'color','k','LineWidth',2);
    
    if str(1) == 'P'
        cx = 2.95 + 0.2 * cos(linspace(0,2*pi));
        cy = 9.57  + 0.2 * sin(linspace(0,2*pi));
        t(6) = patch(cx,cy,bgColor,'EdgeColor','k','LineWidth',1.5);
    end

    set(callback.play_again,'Visible','on')
    set(callback.button,'Visible','off')
    set(fig,'Pointer','arrow')
    set(fig,'WindowButtonMotionFcn',[],'WindowButtonDownFcn',[])
end

function result = CheckForWinner(player,row,col)
% The purpose of this script is to determine whether or not
% the marker that was just placed results in a player victory. 
% 
% The methodology for determining this is simple.  
%   Each marker can be a part of 16 different 
%   vectors that result in 4 in a row. 
%
%   These 16 combinations are created and then checked
%   against the players marker position matrix to see if
%   they have four markers in any of these vectors.
%   If they do, they win. 


% defines the location of the last placed marker
% inside the frame array.
%
% Framing the board with zeros is necessary as to
% avoid errors when searching for a winning vector
% that falls outside the board (on the edges)
pos = [row + 3,col + 3];
frame = zeros(3 * 2 + 6, 3 * 2 + 7);
frame(4:9,4:10) = player; 

% Initializes the directions matrix.  
% This will store the 16 possible array vectors
% that could result in a victory. 
directions = zeros(4,2,16);
i = 1;  % an index to successfully add to this array.

%% start defining directions
%   Each direction will have a diagram where | represents other markers
%   and 0 represents the marker that was just placed. 
%
%   the variable a represents the location of the other markers with
%   respect to the most recently placed marker. 


%% Possible Vertical Combinations For Victory
%    |
%    |   
%    |
%    0
a =[1 0 ; 2 0 ; 3 0];
directions(:,:,i) = [pos; [pos(1) + a(:,1), pos(2) + a(:,2)]];
    i = i + 1;

%    |
%    |   
%    0
%    |
a =[-1 0 ; 1 0 ; 2 0];
directions(:,:,i) = [pos; [pos(1) + a(:,1), pos(2) + a(:,2)]];
    i = i + 1;

%    |
%    0   
%    |
%    |
a =[-2 0 ; -1 0 ; 1 0];
directions(:,:,i) = [pos; [pos(1) + a(:,1), pos(2) + a(:,2)]];
    i = i + 1;

%    0
%    |   
%    |
%    |
a =[-3 0 ; -2 0 ; -1 0];
directions(:,:,i) = [pos; [pos(1) + a(:,1), pos(2) + a(:,2)]];
    i = i + 1;

%% Possible Horizontal Combinations For Victory
%  0  |  |  |
a =[0 1 ; 0 2 ; 0 3]; 
directions(:,:,i) = [pos; [pos(1) + a(:,1), pos(2) + a(:,2)]];
    i = i + 1;

%  |  0  |  |    
a =[0 -1 ; 0 1 ; 0 2]; 
directions(:,:,i) = [pos; [pos(1) + a(:,1), pos(2) + a(:,2)]];
    i = i + 1;

%  |  |  0  |
a =[0 -2 ; 0 -1 ; 0 1]; 
directions(:,:,i) = [pos; [pos(1) + a(:,1), pos(2) + a(:,2)]];
    i = i + 1;

%  |  |  |  0
a =[0 -3 ; 0 -2 ; 0 -1]; 
directions(:,:,i) = [pos; [pos(1) + a(:,1), pos(2) + a(:,2)]];
    i = i + 1;

%% Possible Diagonal (/) Combinations For Victory
%          |
%        |
%      |
%    0
a =[1 1 ; 2 2 ; 3 3]; 
directions(:,:,i) = [pos; [pos(1) + a(:,1), pos(2) + a(:,2)]];
    i = i + 1;

%          |
%        |
%      0
%    |    
a =[-1 -1 ; 1 1 ; 2 2]; 
directions(:,:,i) = [pos; [pos(1) + a(:,1), pos(2) + a(:,2)]];
    i = i + 1;

%          |
%        0
%      |
%    |
a =[-2 -2 ; -1 -1 ; 1 1]; 
directions(:,:,i) = [pos; [pos(1) + a(:,1), pos(2) + a(:,2)]];
    i = i + 1;

%          0
%        |
%      |
%    |
a =[-3 -3 ; -2 -2 ; -1 -1]; 
directions(:,:,i) = [pos; [pos(1) + a(:,1), pos(2) + a(:,2)]];
    i = i + 1;

%% Possible Diagonal (\) Combinations For Victory
% |
%   |
%     |
%       0
a =[-1 1 ; -2 2 ; -3 3]; 
directions(:,:,i) = [pos; [pos(1) + a(:,1), pos(2) + a(:,2)]];
    i = i + 1;

% |
%   |
%     0
%       |
a =[-2 2 ; -1 1 ; 1 -1]; 
directions(:,:,i) = [pos; [pos(1) + a(:,1), pos(2) + a(:,2)]];
    i = i + 1;

% |
%   0
%     |
%       |
a =[-1 1 ; 1 -1 ; 2 -2]; 
directions(:,:,i) = [pos; [pos(1) + a(:,1), pos(2) + a(:,2)]];
    i = i + 1;

% 0
%   |
%     |
%       |
a =[1 -1 ; 2 -2 ; 3 -3]; 
directions(:,:,i) = [pos; [pos(1) + a(:,1), pos(2) + a(:,2)]];


%% Check for a winning vector 
winning_combination= zeros(1,4);  % initialize
result = 0; % loss by default
for i  = 1:16
        x = directions(:,:,i);
        for j = 1:4; 
            winning_combination(j) = frame(x(j,1),x(j,2));
        end
        if sum(winning_combination) == 4
            result = 1;
        end
end





end

function bounce(H,endloc,ball,radius,col)

% coefficient of restitution.

% max cor based on how high you hold the marker before you drop it
Max_COR = 0.3 + (0.1)/(9.6-7.5) * (H - 7.5);

% cor reduced based on how many markers are already in the column
COR = Max_COR - (Max_COR - 0.05)/6 * (endloc-1);

% grab the bouncing data
h = ballbounce(H,COR,3);



h = h + endloc + 0.49; 
h = h( h<=H );



for i = 1:19:length(h)
    if h(i) <= 7.3
        ball.XData = col+0.5 + radius*cos(linspace(0,2*pi));
    end
    cy = h(i) + radius*sin(linspace(0,2*pi));
    ball.YData = cy;
    pause(0.001)    
end

ball.YData = endloc + 0.5 + radius * sin(linspace(0,2*pi));

end

function h=ballbounce(H,COR,n)

% Define constants
g=9.81; % gravity (m/sec^2)
dt=0.001; % time step[temporal resolution] (sec)


% Assign initial conditions
h(1)=H; % h(t0=0)=H=1m
v_previous = 0; % v(t0=0)=0 (no initial velocity)
a = -g;   % a=-g, and always constant

% set index number i to 1 (initial condition for i=1)
i=2;


% repeat calculating velocity and height of the ball
% until the ball hits n times on the ground
for nbounce=1:n
    
    % if current height h(i) has negative number, terminate 'while' loop
    % (it does not physically make sense.)
    while h(i-1)>=0
        % calculate velocity of the ball at given time t(i+1)
        v = v_previous+a*dt;
        % calculate height of the ball at given time t(i+1)
        h(i)=h(i-1) + v * dt;
        v_previous = v;
        % index 'i' increases by 1 to calculate next height
        i=i+1;
    end
    
    
    % delete current height related values and
    % go back to the last height by decreasing i by 1
    % (The last position where the ball is above the ground)
    i=i-1;
    h(i)=[];
    
    % Assume that the ball bounce slightly above the ground,
    % the initial velocity of the ball after bouncing is calculated with
    % the final velocity of the ball before bouncing
    % and coefficient of restitution
    v_previous = -COR * v_previous;
    
    % index 'i' increases by 1 to calculate next height
    % with new condition after the ball bouncing.
end
end

function drop(fig)

callback = guidata(fig);

Row = { [], [], [], [], [], [] };
Row_h = { [], [], [], [], [], [] };
L = zeros(1,6);
max_row = 0;
for i = 1:length(callback.markers)
    H = mean(callback.markers(i).YData);
    idx = round(H - 0.5,0);
    if idx > max_row
        max_row = idx;        
        Max_COR = 0.5;
        COR = Max_COR - (Max_COR - 0.1)/6 * (H-1.5);    
        h = ballbounce(H,COR,3);
        h = h + callback.radius;
        
        Row_h(idx) = {h( h <= H )};
        L(idx) = length(Row_h{idx});
    end
    Row{idx} = [Row{idx}, callback.markers(i)];      
end


ideal_pause_length = [ 1/200 1/175 1/150 1/125 1/100 1/50]; 

a = tic;
for h_idx = 1:max(L)    
    for r = 1:max_row
        if h_idx <= L(r)
            h = Row_h{r};
            set(Row{r},'YData',h(h_idx) + callback.radius*sin(linspace(0,2*pi)))
            if toc(a) > ideal_pause_length(max_row)
                pause(0.001)
                a = tic;
            end
        end
    end   
end


% update the game data
guidata(fig,callback);


end







