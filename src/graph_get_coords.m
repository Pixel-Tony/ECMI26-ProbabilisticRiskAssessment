function [x y] = graph_get_coords(G)
tmp = plot(G, 'Layout', 'force', 'Visible', 'off');
x = tmp.XData;
y = tmp.YData;
end